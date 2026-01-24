//
// MessageSorter.swift
//
// Ported from MailKit (C#) to Swift.
//

import Foundation

public enum MessageSorterError: Error, Sendable, Equatable {
    case emptyOrderBy
    case missingEnvelope
    case missingSortData(OrderByType)
    case unsupportedOrderByType(OrderByType)
}

public enum MessageSorter {
    public static func sort(
        _ messages: [MessageSummary],
        orderBy: [OrderBy]
    ) throws -> [MessageSummary] {
        guard !orderBy.isEmpty else { throw MessageSorterError.emptyOrderBy }
        for rule in orderBy where rule.type == .annotation {
            throw MessageSorterError.unsupportedOrderByType(rule.type)
        }

        try validateSortData(messages, orderBy: orderBy)
        return messages.sorted { lhs, rhs in
            compare(lhs, rhs, orderBy: orderBy) < 0
        }
    }
}

public extension Sequence where Element == MessageSummary {
    func sorted(orderBy: [OrderBy]) throws -> [MessageSummary] {
        try MessageSorter.sort(Array(self), orderBy: orderBy)
    }
}

private extension MessageSorter {
    static func validateSortData(_ messages: [MessageSummary], orderBy: [OrderBy]) throws {
        for message in messages {
            for rule in orderBy {
                switch rule.type {
                case .size:
                    if message.size == nil { throw MessageSorterError.missingSortData(.size) }
                case .modSeq:
                    if message.modSeq == nil { throw MessageSorterError.missingSortData(.modSeq) }
                case .annotation:
                    throw MessageSorterError.unsupportedOrderByType(.annotation)
                case .arrival:
                    continue
                case .cc, .date, .displayFrom, .displayTo, .from, .subject, .to:
                    if message.envelope == nil { throw MessageSorterError.missingEnvelope }
                }
            }
        }
    }

    static func compare(_ lhs: MessageSummary, _ rhs: MessageSummary, orderBy: [OrderBy]) -> Int {
        for rule in orderBy {
            let cmp: Int
            switch rule.type {
            case .annotation:
                cmp = 0
            case .arrival:
                cmp = compareInts(lhs.index, rhs.index)
            case .cc:
                cmp = compareMailboxAddresses(lhs.envelope?.cc ?? [], rhs.envelope?.cc ?? [])
            case .date:
                cmp = compareDates(lhs.envelope?.date, rhs.envelope?.date)
            case .displayFrom:
                cmp = compareDisplayNames(lhs.envelope?.from ?? [], rhs.envelope?.from ?? [])
            case .displayTo:
                cmp = compareDisplayNames(lhs.envelope?.to ?? [], rhs.envelope?.to ?? [])
            case .from:
                cmp = compareMailboxAddresses(lhs.envelope?.from ?? [], rhs.envelope?.from ?? [])
            case .modSeq:
                cmp = compareUInt64s(lhs.modSeq ?? 0, rhs.modSeq ?? 0)
            case .size:
                cmp = compareInts(lhs.size ?? 0, rhs.size ?? 0)
            case .subject:
                cmp = compareStrings(lhs.envelope?.subject, rhs.envelope?.subject)
            case .to:
                cmp = compareMailboxAddresses(lhs.envelope?.to ?? [], rhs.envelope?.to ?? [])
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
}
