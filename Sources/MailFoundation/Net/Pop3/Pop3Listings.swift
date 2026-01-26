//
// Pop3Listings.swift
//
// POP3 LIST/UIDL/STAT parsing helpers.
//

/// Represents a single item from a LIST command response.
///
/// The LIST command returns the message index and size in bytes for each
/// message in the mailbox.
///
/// ## Response Format
///
/// Each line of the LIST response contains:
/// ```
/// <message-number> <size-in-octets>
/// ```
///
/// ## Usage
///
/// ```swift
/// let listings = try folder.list()
/// for item in listings {
///     print("Message \(item.index): \(item.size) bytes")
/// }
/// ```
///
/// ## See Also
///
/// - ``Pop3Folder/list()`` for retrieving listings
/// - ``Pop3UidlItem`` for unique identifiers
public struct Pop3ListItem: Sendable, Equatable {
    /// The 1-based message index.
    public let index: Int

    /// The message size in bytes (octets).
    public let size: Int

    /// Parses a single LIST response line.
    ///
    /// - Parameter line: The response line in format "index size".
    /// - Returns: The parsed item, or nil if parsing fails.
    public static func parseLine(_ line: String) -> Pop3ListItem? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2,
              let index = Int(parts[0]),
              let size = Int(parts[1]) else {
            return nil
        }
        return Pop3ListItem(index: index, size: size)
    }
}

/// Represents a single item from a UIDL command response.
///
/// The UIDL command returns unique identifiers for messages. Unlike message
/// indices which can change when messages are deleted, UIDs are persistent
/// and can be used to track messages across sessions.
///
/// ## Response Format
///
/// Each line of the UIDL response contains:
/// ```
/// <message-number> <unique-id>
/// ```
///
/// ## Usage
///
/// ```swift
/// let uidls = try folder.uidl()
/// for item in uidls {
///     print("Message \(item.index): UID = \(item.uid)")
/// }
/// ```
///
/// ## See Also
///
/// - ``Pop3Folder/uidl()`` for retrieving unique identifiers
/// - ``Pop3ListItem`` for message sizes
public struct Pop3UidlItem: Sendable, Equatable {
    /// The 1-based message index.
    public let index: Int

    /// The unique identifier for the message.
    ///
    /// This identifier is persistent across sessions and can be used to
    /// track which messages have been downloaded or deleted.
    public let uid: String

    /// Parses a single UIDL response line.
    ///
    /// - Parameter line: The response line in format "index uid".
    /// - Returns: The parsed item, or nil if parsing fails.
    public static func parseLine(_ line: String) -> Pop3UidlItem? {
        let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2, let index = Int(parts[0]) else {
            return nil
        }
        return Pop3UidlItem(index: index, uid: String(parts[1]))
    }
}

/// Represents the response from a STAT command.
///
/// The STAT command returns the total number of messages in the mailbox
/// and their combined size in bytes.
///
/// ## Response Format
///
/// The STAT response is:
/// ```
/// +OK <message-count> <total-size>
/// ```
///
/// ## Usage
///
/// ```swift
/// let stat = try folder.stat()
/// print("You have \(stat.count) messages totaling \(stat.size) bytes")
/// ```
///
/// ## See Also
///
/// - ``Pop3Folder/stat()`` for retrieving mailbox statistics
/// - ``Pop3ListItem`` for individual message sizes
public struct Pop3StatResponse: Sendable, Equatable {
    /// The number of messages in the mailbox.
    public let count: Int

    /// The total size of all messages in bytes.
    public let size: Int

    /// Parses a STAT response.
    ///
    /// - Parameter response: The server's response to the STAT command.
    /// - Returns: The parsed statistics, or nil if parsing fails.
    public static func parse(_ response: Pop3Response) -> Pop3StatResponse? {
        guard response.isSuccess else { return nil }
        let parts = response.message.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2,
              let count = Int(parts[0]),
              let size = Int(parts[1]) else {
            return nil
        }
        return Pop3StatResponse(count: count, size: size)
    }
}

/// Parser for LIST command multiline responses.
///
/// Use this to parse the body lines of a LIST response into ``Pop3ListItem`` objects.
public enum Pop3ListParser {
    /// Parses multiple LIST response lines.
    ///
    /// - Parameter lines: The body lines from a LIST multiline response.
    /// - Returns: An array of parsed list items.
    public static func parse(_ lines: [String]) -> [Pop3ListItem] {
        lines.compactMap(Pop3ListItem.parseLine)
    }
}

/// Parser for UIDL command multiline responses.
///
/// Use this to parse the body lines of a UIDL response into ``Pop3UidlItem`` objects.
public enum Pop3UidlParser {
    /// Parses multiple UIDL response lines.
    ///
    /// - Parameter lines: The body lines from a UIDL multiline response.
    /// - Returns: An array of parsed UIDL items.
    public static func parse(_ lines: [String]) -> [Pop3UidlItem] {
        lines.compactMap(Pop3UidlItem.parseLine)
    }
}
