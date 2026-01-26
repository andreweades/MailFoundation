//
// MessageThreader.swift
//
// Ported from MailKit (C#) to Swift.
//

import Foundation

/// Errors that can occur during message threading.
public enum MessageThreaderError: Error, Sendable, Equatable {
    /// A message is missing its envelope data.
    ///
    /// Threading requires envelope data (subject, message-id, references)
    /// to be fetched for each message.
    case missingEnvelope

    /// The orderBy parameter is empty.
    ///
    /// At least one sort criterion must be specified.
    case emptyOrderBy

    /// The specified sort type is not supported.
    ///
    /// - Parameter type: The unsupported order-by type.
    case unsupportedOrderByType(OrderByType)

    /// A message is missing required data for the specified sort type.
    ///
    /// - Parameter type: The order-by type that requires missing data.
    case missingSortData(OrderByType)
}

/// A utility for threading messages into conversation trees.
///
/// `MessageThreader` implements the IMAP THREAD extension algorithms for organizing
/// messages into conversation threads. It supports both the `ORDEREDSUBJECT` and
/// `REFERENCES` algorithms as defined in RFC 5256.
///
/// ## Threading Algorithms
///
/// - **References**: Uses Message-Id, In-Reply-To, and References headers to build
///   an accurate thread tree. This is the recommended algorithm for most use cases.
///
/// - **Ordered Subject**: Groups messages by normalized subject and sorts by date.
///   Simpler but less accurate than the references algorithm.
///
/// ## Topics
///
/// ### Threading Methods
/// - ``thread(_:algorithm:orderBy:)``
///
/// ## Example
///
/// ```swift
/// // Thread messages using the references algorithm
/// let threads = try MessageThreader.thread(
///     messages,
///     algorithm: .references,
///     orderBy: [.date]
/// )
///
/// // Or use the sequence extension
/// let threads = try messages.thread(
///     algorithm: .references,
///     orderBy: [.date]
/// )
/// ```
public enum MessageThreader {
    /// Threads messages into a conversation tree.
    ///
    /// This method organizes a collection of messages into a tree structure based on
    /// their relationships (replies, references) or subjects. The resulting threads
    /// can be displayed hierarchically to show conversation flow.
    ///
    /// - Parameters:
    ///   - messages: The messages to thread. Each message must have its envelope fetched.
    ///   - algorithm: The threading algorithm to use.
    ///   - orderBy: The sort criteria for ordering threads. Defaults to arrival order.
    ///
    /// - Returns: An array of root-level thread nodes.
    ///
    /// - Throws: ``MessageThreaderError`` if threading fails due to missing data or
    ///   invalid parameters.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let threads = try MessageThreader.thread(
    ///     messages,
    ///     algorithm: .references,
    ///     orderBy: [OrderBy(.date, order: .descending)]
    /// )
    /// ```
    public static func thread(
        _ messages: [MessageSummary],
        algorithm: ThreadingAlgorithm,
        orderBy: [OrderBy] = [.arrival]
    ) throws -> [MessageThread] {
        guard !orderBy.isEmpty else { throw MessageThreaderError.emptyOrderBy }

        for rule in orderBy where rule.type == .annotation {
            throw MessageThreaderError.unsupportedOrderByType(rule.type)
        }

        try validateSortData(messages, orderBy: orderBy)

        switch algorithm {
        case .orderedSubject:
            return try threadBySubject(messages, orderBy: orderBy)
        case .references:
            return try threadByReferences(messages, orderBy: orderBy)
        }
    }
}

public extension Sequence where Element == MessageSummary {
    /// Threads the messages in this sequence into a conversation tree.
    ///
    /// This is a convenience method that calls ``MessageThreader/thread(_:algorithm:orderBy:)``
    /// on the sequence elements.
    ///
    /// - Parameters:
    ///   - algorithm: The threading algorithm to use.
    ///   - orderBy: The sort criteria for ordering threads. Defaults to arrival order.
    ///
    /// - Returns: An array of root-level thread nodes.
    ///
    /// - Throws: ``MessageThreaderError`` if threading fails.
    func thread(
        algorithm: ThreadingAlgorithm,
        orderBy: [OrderBy] = [.arrival]
    ) throws -> [MessageThread] {
        try MessageThreader.thread(Array(self), algorithm: algorithm, orderBy: orderBy)
    }
}

private extension MessageThreader {
    final class ThreadableNode {
        var message: MessageSummary?
        var children: [ThreadableNode] = []
        weak var parent: ThreadableNode?

        init(_ message: MessageSummary?) {
            self.message = message
        }

        var hasParent: Bool {
            parent != nil
        }

        var hasChildren: Bool {
            !children.isEmpty
        }

        var normalizedSubject: String {
            if let message {
                return message.normalizedSubject
            }
            return children.first?.normalizedSubject ?? ""
        }

        var isReply: Bool {
            if let message {
                return message.isReply
            }
            return children.first?.isReply ?? false
        }

        var index: Int {
            if let message {
                return message.index
            }
            return children.first?.index ?? 0
        }

        var date: Date? {
            if let message {
                return message.envelope?.date
            }
            return children.first?.date
        }

        var subject: String? {
            if let message {
                return message.envelope?.subject
            }
            return children.first?.subject
        }

        var from: [ImapAddress] {
            if let message, let envelope = message.envelope {
                return envelope.from
            }
            return children.first?.from ?? []
        }

        var to: [ImapAddress] {
            if let message, let envelope = message.envelope {
                return envelope.to
            }
            return children.first?.to ?? []
        }

        var cc: [ImapAddress] {
            if let message, let envelope = message.envelope {
                return envelope.cc
            }
            return children.first?.cc ?? []
        }

        var size: Int {
            if let message, let size = message.size {
                return size
            }
            return children.first?.size ?? 0
        }

        var modSeq: UInt64 {
            if let message, let modSeq = message.modSeq {
                return modSeq
            }
            return children.first?.modSeq ?? 0
        }
    }

    static func threadByReferences(_ messages: [MessageSummary], orderBy: [OrderBy]) throws -> [MessageThread] {
        let ordered = try createIdTable(messages)
        let root = createRoot(ordered)
        pruneEmptyContainers(root)
        groupBySubject(root)
        return buildThreads(from: root, orderBy: orderBy)
    }

    static func threadBySubject(_ messages: [MessageSummary], orderBy: [OrderBy]) throws -> [MessageThread] {
        let root = ThreadableNode(nil)
        for message in messages {
            guard message.envelope != nil else { throw MessageThreaderError.missingEnvelope }
            root.children.append(ThreadableNode(message))
        }
        groupBySubject(root)
        return buildThreads(from: root, orderBy: orderBy)
    }

    static func createIdTable(_ messages: [MessageSummary]) throws -> [ThreadableNode] {
        var ids: [String: ThreadableNode] = [:]
        var ordered: [ThreadableNode] = []

        for message in messages {
            guard let envelope = message.envelope else { throw MessageThreaderError.missingEnvelope }

            var id = envelope.messageId
            if id == nil || id?.isEmpty == true {
                id = generateMessageId()
            }

            let key = normalizeKey(id ?? "")
            var node = ids[key]

            if let existing = node {
                if existing.message == nil {
                    existing.message = message
                } else {
                    id = generateMessageId()
                    node = nil
                }
            }

            if node == nil {
                let created = ThreadableNode(message)
                ids[normalizeKey(id ?? "")] = created
                ordered.append(created)
                node = created
            }

            var parent: ThreadableNode?
            let references = message.references?.ids ?? []

            for reference in references {
                let referenceKey = normalizeKey(reference)
                let referenced = ids[referenceKey] ?? {
                    let placeholder = ThreadableNode(nil)
                    ids[referenceKey] = placeholder
                    ordered.append(placeholder)
                    return placeholder
                }()

                if let parentNode = parent,
                   referenced.parent == nil,
                   parentNode !== referenced,
                   !parentNode.children.contains(where: { $0 === referenced }) {
                    parentNode.children.append(referenced)
                    referenced.parent = parentNode
                }

                parent = referenced
            }

            if let parentNode = parent,
               parentNode === node || node?.children.contains(where: { $0 === parentNode }) == true {
                parent = nil
            }

            if let node, node.hasParent, let oldParent = node.parent {
                oldParent.children.removeAll(where: { $0 === node })
                node.parent = nil
            }

            if let node, let parentNode = parent {
                parentNode.children.append(node)
                node.parent = parentNode
            }
        }

        return ordered
    }

    static func validateSortData(_ messages: [MessageSummary], orderBy: [OrderBy]) throws {
        for message in messages {
            guard message.envelope != nil else { throw MessageThreaderError.missingEnvelope }
            for rule in orderBy {
                switch rule.type {
                case .size:
                    if message.size == nil { throw MessageThreaderError.missingSortData(.size) }
                case .modSeq:
                    if message.modSeq == nil { throw MessageThreaderError.missingSortData(.modSeq) }
                case .annotation:
                    throw MessageThreaderError.unsupportedOrderByType(.annotation)
                case .arrival, .cc, .date, .displayFrom, .displayTo, .from, .subject, .to:
                    continue
                }
            }
        }
    }

    static func createRoot(_ ordered: [ThreadableNode]) -> ThreadableNode {
        let root = ThreadableNode(nil)
        for node in ordered where node.parent == nil {
            root.children.append(node)
        }
        return root
    }

    static func pruneEmptyContainers(_ root: ThreadableNode) {
        var index = 0
        while index < root.children.count {
            let node = root.children[index]
            if node.message == nil && node.children.isEmpty {
                root.children.remove(at: index)
                continue
            }

            if node.message == nil && node.hasChildren && (node.hasParent || node.children.count == 1) {
                root.children.remove(at: index)
                for child in node.children {
                    child.parent = node.parent
                    root.children.append(child)
                }
                node.children.removeAll()
                continue
            }

            if node.hasChildren {
                pruneEmptyContainers(node)
            }

            index += 1
        }
    }

    static func groupBySubject(_ root: ThreadableNode) {
        var subjects: [String: ThreadableNode] = [:]
        var count = 0

        for node in root.children {
            let subject = node.normalizedSubject
            if subject.isEmpty { continue }
            let key = normalizeKey(subject)

            if let match = subjects[key] {
                if node.message == nil && match.message != nil {
                    subjects[key] = node
                    count += 1
                } else if let matchMessage = match.message,
                          matchMessage.isReply,
                          let nodeMessage = node.message,
                          !nodeMessage.isReply {
                    subjects[key] = node
                    count += 1
                }
            } else {
                subjects[key] = node
                count += 1
            }
        }

        if count == 0 { return }

        var index = 0
        while index < root.children.count {
            let node = root.children[index]
            let subject = node.normalizedSubject
            if subject.isEmpty {
                index += 1
                continue
            }

            let key = normalizeKey(subject)
            guard let match = subjects[key] else {
                index += 1
                continue
            }

            if match === node {
                index += 1
                continue
            }

            root.children.remove(at: index)

            if match.message == nil && node.message == nil {
                match.children.append(contentsOf: node.children)
                node.children.removeAll()
            } else if match.message == nil && node.message != nil {
                match.children.append(node)
                node.parent = match
            } else if node.isReply && match.message?.isReply == false {
                match.children.append(node)
                node.parent = match
            } else {
                let dummy = match
                let clone = ThreadableNode(dummy.message)
                clone.children.append(contentsOf: dummy.children)
                dummy.children.removeAll()
                dummy.message = nil
                dummy.children.append(clone)
                dummy.children.append(node)
                clone.parent = dummy
                node.parent = dummy
            }

            continue
        }
    }

    static func buildThreads(from root: ThreadableNode, orderBy: [OrderBy]) -> [MessageThread] {
        let sortedChildren = root.children.sorted { lhs, rhs in
            compare(lhs, rhs, orderBy: orderBy) < 0
        }

        return sortedChildren.map { node in
            let childThreads = buildThreads(from: node, orderBy: orderBy)
            return MessageThread(message: node.message, children: childThreads)
        }
    }

    static func compare(_ lhs: ThreadableNode, _ rhs: ThreadableNode, orderBy: [OrderBy]) -> Int {
        for rule in orderBy {
            let cmp: Int
            switch rule.type {
            case .annotation:
                cmp = 0
            case .arrival:
                cmp = compareInts(lhs.index, rhs.index)
            case .cc:
                cmp = compareMailboxAddresses(lhs.cc, rhs.cc)
            case .date:
                cmp = compareDates(lhs.date, rhs.date)
            case .displayFrom:
                cmp = compareDisplayNames(lhs.from, rhs.from)
            case .displayTo:
                cmp = compareDisplayNames(lhs.to, rhs.to)
            case .from:
                cmp = compareMailboxAddresses(lhs.from, rhs.from)
            case .modSeq:
                cmp = compareUInt64s(lhs.modSeq, rhs.modSeq)
            case .size:
                cmp = compareInts(lhs.size, rhs.size)
            case .subject:
                cmp = compareStrings(lhs.subject, rhs.subject)
            case .to:
                cmp = compareMailboxAddresses(lhs.to, rhs.to)
            }

            if cmp == 0 { continue }
            return rule.order == .descending ? (cmp * -1) : cmp
        }

        return 0
    }

    static func compareInts(_ lhs: Int, _ rhs: Int) -> Int {
        if lhs == rhs { return 0 }
        return lhs < rhs ? -1 : 1
    }

    static func compareUInt64s(_ lhs: UInt64, _ rhs: UInt64) -> Int {
        if lhs == rhs { return 0 }
        return lhs < rhs ? -1 : 1
    }

    static func compareDates(_ lhs: Date?, _ rhs: Date?) -> Int {
        let left = lhs ?? Date.distantPast
        let right = rhs ?? Date.distantPast
        if left == right { return 0 }
        return left < right ? -1 : 1
    }

    static func compareStrings(_ lhs: String?, _ rhs: String?) -> Int {
        let left = lhs ?? ""
        let right = rhs ?? ""
        let result = left.caseInsensitiveCompare(right)
        switch result {
        case .orderedAscending: return -1
        case .orderedDescending: return 1
        case .orderedSame: return 0
        }
    }

    static func compareDisplayNames(_ lhs: [ImapAddress], _ rhs: [ImapAddress]) -> Int {
        let list1 = flattenMailboxes(lhs)
        let list2 = flattenMailboxes(rhs)
        var index = 0

        while index < list1.count && index < list2.count {
            let name1 = list1[index].name ?? ""
            let name2 = list2[index].name ?? ""
            let result = name1.caseInsensitiveCompare(name2)
            if result != .orderedSame {
                return result == .orderedAscending ? -1 : 1
            }
            index += 1
        }

        if list1.count == list2.count { return 0 }
        return list1.count > list2.count ? 1 : -1
    }

    static func compareMailboxAddresses(_ lhs: [ImapAddress], _ rhs: [ImapAddress]) -> Int {
        let list1 = flattenMailboxes(lhs)
        let list2 = flattenMailboxes(rhs)
        var index = 0

        while index < list1.count && index < list2.count {
            let address1 = list1[index].address ?? ""
            let address2 = list2[index].address ?? ""
            let result = address1.caseInsensitiveCompare(address2)
            if result != .orderedSame {
                return result == .orderedAscending ? -1 : 1
            }
            index += 1
        }

        if list1.count == list2.count { return 0 }
        return list1.count > list2.count ? 1 : -1
    }

    static func flattenMailboxes(_ addresses: [ImapAddress]) -> [ImapMailboxAddress] {
        var result: [ImapMailboxAddress] = []
        for address in addresses {
            switch address {
            case .mailbox(let mailbox):
                result.append(mailbox)
            case .group(let group):
                result.append(contentsOf: group.members)
            }
        }
        return result
    }

    static func normalizeKey(_ value: String) -> String {
        value.lowercased()
    }

    static func generateMessageId() -> String {
        "\(UUID().uuidString)@generated.invalid"
    }
}
