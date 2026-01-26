//
// MessageThread.swift
//
// Ported from MailKit (C#) to Swift.
//

/// A node in a message thread tree.
///
/// `MessageThread` represents a node in a hierarchical structure of threaded messages.
/// Each node may contain a message (or be a placeholder for a missing message in the
/// thread chain) and may have child nodes representing replies.
///
/// Thread trees are typically built using ``MessageThreader`` with either the
/// ``ThreadingAlgorithm/orderedSubject`` or ``ThreadingAlgorithm/references``
/// algorithm.
///
/// ## Topics
///
/// ### Properties
/// - ``message``
/// - ``uniqueId``
/// - ``children``
///
/// ### Creating Threads
/// - ``init(message:children:)``
/// - ``init(uniqueId:children:)``
///
/// ## Example
///
/// ```swift
/// func printThread(_ thread: MessageThread, indent: Int = 0) {
///     let prefix = String(repeating: "  ", count: indent)
///     if let message = thread.message {
///         print("\(prefix)\(message.envelope?.subject ?? "No subject")")
///     } else {
///         print("\(prefix)(placeholder)")
///     }
///     for child in thread.children {
///         printThread(child, indent: indent + 1)
///     }
/// }
///
/// let threads = try MessageThreader.thread(messages, algorithm: .references)
/// for thread in threads {
///     printThread(thread)
/// }
/// ```
public struct MessageThread: Sendable, Equatable {
    /// The message at this node in the thread, if available.
    ///
    /// This may be `nil` for placeholder nodes that represent messages referenced
    /// by other messages but not present in the fetched set. Such placeholders
    /// maintain the thread hierarchy even when some messages are missing.
    public let message: MessageSummary?

    /// The unique identifier of the message, if available.
    ///
    /// This is extracted from the message's unique ID for convenience.
    /// If the node is a placeholder (``message`` is `nil`) or the message
    /// does not have a valid unique ID, this will be `nil`.
    public let uniqueId: UniqueId?

    /// The child threads (replies) under this node.
    ///
    /// An empty array indicates this is a leaf node with no replies.
    public let children: [MessageThread]

    /// Creates a thread node with a message and optional children.
    ///
    /// - Parameters:
    ///   - message: The message at this node, or `nil` for a placeholder.
    ///   - children: The child thread nodes (replies). Defaults to an empty array.
    public init(message: MessageSummary?, children: [MessageThread] = []) {
        self.message = message
        if let message, let uid = message.uniqueId, uid.isValid {
            self.uniqueId = uid
        } else {
            self.uniqueId = nil
        }
        self.children = children
    }

    /// Creates a placeholder thread node with a unique ID and optional children.
    ///
    /// Use this initializer for placeholder nodes that represent messages
    /// referenced in the thread but not present in the message set.
    ///
    /// - Parameters:
    ///   - uniqueId: The unique identifier for the placeholder.
    ///   - children: The child thread nodes (replies). Defaults to an empty array.
    public init(uniqueId: UniqueId?, children: [MessageThread] = []) {
        self.message = nil
        self.uniqueId = uniqueId
        self.children = children
    }
}
