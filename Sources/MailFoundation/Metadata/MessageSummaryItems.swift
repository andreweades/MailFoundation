//
// MessageSummaryItems.swift
//
// Ported from MailKit (C#) to Swift.
//

/// An option set specifying which message summary items to fetch.
///
/// Use `MessageSummaryItems` to specify which properties of a ``MessageSummary`` should
/// be fetched from the mail server. The properties of the `MessageSummary` that will be
/// available depend on which items are requested.
///
/// ## Topics
///
/// ### Basic Items
/// - ``flags``
/// - ``uniqueId``
/// - ``internalDate``
/// - ``size``
///
/// ### Envelope and Structure
/// - ``envelope``
/// - ``body``
/// - ``bodyStructure``
///
/// ### Extended Items
/// - ``modSeq``
/// - ``references``
/// - ``headers``
/// - ``annotations``
/// - ``previewText``
/// - ``saveDate``
///
/// ### OBJECTID Extension
/// - ``emailId``
/// - ``threadId``
///
/// ### GMail Extension
/// - ``gmailMessageId``
/// - ``gmailThreadId``
/// - ``gmailLabels``
///
/// ### Convenience Sets
/// - ``all``
/// - ``fast``
/// - ``full``
///
/// ## Example
///
/// ```swift
/// // Fetch envelope and flags for threading
/// let items: MessageSummaryItems = [.envelope, .flags, .uniqueId]
///
/// // Use a convenience set
/// let basicItems = MessageSummaryItems.fast  // [.flags, .internalDate, .size]
/// ```
public struct MessageSummaryItems: OptionSet, Sendable {
    /// The raw value of the option set.
    public let rawValue: UInt32

    /// Creates a message summary items option set from a raw value.
    ///
    /// - Parameter rawValue: The raw value representing the items.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// No message summary items are requested.
    public static let none = MessageSummaryItems([])

    /// Request message annotations.
    ///
    /// Requires server support for the ANNOTATE extension (RFC 5257).
    public static let annotations = MessageSummaryItems(rawValue: 1 << 0)

    /// Request the basic body structure of the message.
    ///
    /// The basic body structure provides MIME part information without
    /// extension data.
    public static let body = MessageSummaryItems(rawValue: 1 << 1)

    /// Request the full body structure of the message.
    ///
    /// The full body structure provides detailed MIME part information
    /// including extension data like disposition and language.
    public static let bodyStructure = MessageSummaryItems(rawValue: 1 << 2)

    /// Request the message envelope.
    ///
    /// The envelope contains addressing information including From, To, Cc,
    /// Subject, Date, Message-Id, and In-Reply-To.
    public static let envelope = MessageSummaryItems(rawValue: 1 << 3)

    /// Request the message flags.
    ///
    /// Returns the standard IMAP flags (seen, answered, flagged, deleted, draft)
    /// and any user-defined keywords.
    public static let flags = MessageSummaryItems(rawValue: 1 << 4)

    /// Request the internal date of the message.
    ///
    /// The internal date is when the message was received by the server.
    public static let internalDate = MessageSummaryItems(rawValue: 1 << 5)

    /// Request the size of the message in bytes.
    ///
    /// Returns the RFC 822 size of the message.
    public static let size = MessageSummaryItems(rawValue: 1 << 6)

    /// Request the modification sequence number.
    ///
    /// Requires server support for the CONDSTORE extension (RFC 7162).
    /// The mod-sequence value tracks changes to the message.
    public static let modSeq = MessageSummaryItems(rawValue: 1 << 7)

    /// Request the message references.
    ///
    /// Returns the message-ids from the References and In-Reply-To headers,
    /// used for message threading.
    public static let references = MessageSummaryItems(rawValue: 1 << 8)

    /// Request the unique identifier of the message.
    ///
    /// The UID is a stable identifier for the message within the mailbox.
    public static let uniqueId = MessageSummaryItems(rawValue: 1 << 9)

    /// Request the globally unique message identifier.
    ///
    /// Requires server support for the OBJECTID extension (RFC 8474).
    /// This is a globally unique identifier for the message.
    public static let emailId = MessageSummaryItems(rawValue: 1 << 10)

    /// Request the globally unique thread identifier.
    ///
    /// Requires server support for the OBJECTID extension (RFC 8474).
    /// This identifies the conversation thread the message belongs to.
    public static let threadId = MessageSummaryItems(rawValue: 1 << 11)

    /// Request the GMail message identifier.
    ///
    /// This is a GMail-specific extension that provides a unique identifier
    /// for the message across all GMail folders.
    public static let gmailMessageId = MessageSummaryItems(rawValue: 1 << 12)

    /// Request the GMail thread identifier.
    ///
    /// This is a GMail-specific extension that provides a unique identifier
    /// for the conversation thread.
    public static let gmailThreadId = MessageSummaryItems(rawValue: 1 << 13)

    /// Request the GMail labels.
    ///
    /// This is a GMail-specific extension that returns the labels applied
    /// to the message.
    public static let gmailLabels = MessageSummaryItems(rawValue: 1 << 14)

    /// Request all message headers.
    ///
    /// Returns all header fields from the message. For fetching specific
    /// headers only, use a custom fetch request.
    public static let headers = MessageSummaryItems(rawValue: 1 << 15)

    /// Request the message preview text.
    ///
    /// Returns a short snippet of the message body text, typically used
    /// for message list previews.
    public static let previewText = MessageSummaryItems(rawValue: 1 << 16)

    /// Request the save date of the message.
    ///
    /// Requires server support for the SAVEDATE extension (RFC 8514).
    /// The save date is when the message was saved to the current mailbox.
    public static let saveDate = MessageSummaryItems(rawValue: 1 << 17)

    /// Convenience set equivalent to IMAP's ALL macro.
    ///
    /// Includes: ``envelope``, ``flags``, ``internalDate``, ``size``.
    public static let all: MessageSummaryItems = [.envelope, .flags, .internalDate, .size]

    /// Convenience set equivalent to IMAP's FAST macro.
    ///
    /// Includes: ``flags``, ``internalDate``, ``size``.
    public static let fast: MessageSummaryItems = [.flags, .internalDate, .size]

    /// Convenience set equivalent to IMAP's FULL macro.
    ///
    /// Includes: ``body``, ``envelope``, ``flags``, ``internalDate``, ``size``.
    public static let full: MessageSummaryItems = [.body, .envelope, .flags, .internalDate, .size]
}
