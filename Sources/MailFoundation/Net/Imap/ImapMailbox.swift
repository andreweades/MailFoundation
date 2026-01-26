//
// Author: Jeffrey Stedfast <jestedfa@microsoft.com>
//
// Copyright (c) 2013-2026 .NET Foundation and Contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

//
// ImapMailbox.swift
//
// IMAP mailbox attribute modeling.
//

/// Represents an attribute of an IMAP mailbox.
///
/// Mailbox attributes are returned by the LIST and LSUB commands and provide
/// information about the mailbox's properties and special uses.
///
/// ## Standard Attributes
///
/// - `hasChildren`, `hasNoChildren` - Whether the mailbox has subfolders
/// - `noSelect` - Mailbox cannot be selected (folder container only)
/// - `noInferiors` - Cannot create subfolders under this mailbox
/// - `marked`, `unmarked` - Interest markers for the mailbox
///
/// ## Special-Use Attributes (RFC 6154)
///
/// - `inbox` - The INBOX folder
/// - `all` - All messages (Gmail "All Mail")
/// - `archive` - Archive folder
/// - `drafts` - Drafts folder
/// - `flagged` - Starred/flagged messages
/// - `junk` - Spam folder
/// - `sent` - Sent messages
/// - `trash` - Deleted messages
///
/// ## See Also
///
/// - ``ImapMailbox``
/// - ``ImapFolder``
public enum ImapMailboxAttribute: Sendable, Equatable {
    case hasChildren
    case hasNoChildren
    case noSelect
    case noInferiors
    case marked
    case unmarked
    case nonExistent
    case subscribed
    case remote
    case noRename
    case readOnly
    case noMail
    case noAccess
    case inbox
    case all
    case archive
    case drafts
    case flagged
    case junk
    case sent
    case trash
    case important
    case other(String)

    public init(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix("\\") ? String(trimmed.dropFirst()) : trimmed
        switch normalized.uppercased() {
        case "HASCHILDREN":
            self = .hasChildren
        case "HASNOCHILDREN":
            self = .hasNoChildren
        case "NOSELECT":
            self = .noSelect
        case "NOINFERIORS":
            self = .noInferiors
        case "MARKED":
            self = .marked
        case "UNMARKED":
            self = .unmarked
        case "NONEXISTENT":
            self = .nonExistent
        case "SUBSCRIBED":
            self = .subscribed
        case "REMOTE":
            self = .remote
        case "NORENAME":
            self = .noRename
        case "READ-ONLY", "READONLY":
            self = .readOnly
        case "NOMAIL":
            self = .noMail
        case "NOACCESS":
            self = .noAccess
        case "INBOX":
            self = .inbox
        case "ALL":
            self = .all
        case "ARCHIVE":
            self = .archive
        case "DRAFTS":
            self = .drafts
        case "FLAGGED":
            self = .flagged
        case "JUNK":
            self = .junk
        case "SENT":
            self = .sent
        case "TRASH":
            self = .trash
        case "IMPORTANT":
            self = .important
        default:
            self = .other(normalized)
        }
    }

    /// Whether this attribute indicates a special-use folder.
    ///
    /// Special-use folders are defined in RFC 6154 and include archive, drafts,
    /// flagged, junk, sent, trash, and important.
    public var isSpecialUse: Bool {
        switch self {
        case .all, .archive, .drafts, .flagged, .junk, .sent, .trash, .important:
            return true
        default:
            return false
        }
    }
}

/// Represents an IMAP mailbox (folder) with its metadata.
///
/// An `ImapMailbox` contains the mailbox name, hierarchy delimiter, and attributes
/// as returned by the LIST or LSUB command. This is the raw mailbox information;
/// for folder operations, use ``ImapFolder``.
///
/// ## Properties
///
/// - `name` - The encoded mailbox name (may contain modified UTF-7)
/// - `decodedName` - The human-readable decoded name
/// - `delimiter` - The hierarchy separator (e.g., "/" or ".")
/// - `attributes` - The mailbox attributes (e.g., `\Noselect`, `\HasChildren`)
///
/// ## Example
///
/// ```swift
/// let folders = try store.getFolders(reference: "", pattern: "*")
/// for folder in folders {
///     let mailbox = folder.mailbox
///     print("Name: \(mailbox.decodedName)")
///     if let special = mailbox.specialUse {
///         print("Special use: \(special)")
///     }
///     if mailbox.isSelectable {
///         print("Can be opened")
///     }
/// }
/// ```
///
/// ## See Also
///
/// - ``ImapMailboxAttribute``
/// - ``ImapFolder``
public struct ImapMailbox: Sendable, Equatable {
    /// The kind of list response (LIST or LSUB).
    public let kind: ImapMailboxListKind

    /// The encoded mailbox name as it appears on the server.
    ///
    /// This may contain modified UTF-7 encoding for international characters.
    public let name: String

    /// The decoded, human-readable mailbox name.
    public let decodedName: String

    /// The hierarchy delimiter character (e.g., "/" or ".").
    ///
    /// This character separates levels in the mailbox hierarchy.
    /// A `nil` value indicates the mailbox has no hierarchy.
    public let delimiter: String?

    /// The raw attribute strings from the server response.
    public let rawAttributes: [String]

    /// The parsed mailbox attributes.
    public let attributes: [ImapMailboxAttribute]

    /// Creates a new mailbox with the specified properties.
    ///
    /// - Parameters:
    ///   - kind: The type of list response.
    ///   - name: The encoded mailbox name.
    ///   - delimiter: The hierarchy delimiter.
    ///   - attributes: The raw attribute strings.
    public init(kind: ImapMailboxListKind, name: String, delimiter: String?, attributes: [String]) {
        self.kind = kind
        self.name = name
        self.decodedName = ImapMailboxEncoding.decode(name)
        self.delimiter = delimiter
        self.rawAttributes = attributes
        self.attributes = attributes.map { ImapMailboxAttribute(rawValue: $0) }
    }

    /// Checks if the mailbox has a specific attribute.
    ///
    /// - Parameter attribute: The attribute to check for.
    /// - Returns: `true` if the mailbox has the attribute.
    public func hasAttribute(_ attribute: ImapMailboxAttribute) -> Bool {
        attributes.contains(attribute)
    }

    /// The special-use attribute of this mailbox, if any.
    ///
    /// Returns the first special-use attribute found (e.g., `.drafts`, `.sent`).
    public var specialUse: ImapMailboxAttribute? {
        attributes.first { $0.isSpecialUse }
    }

    /// Whether the mailbox can be selected (opened).
    ///
    /// Returns `false` if the mailbox has the `\Noselect` or `\NonExistent` attribute.
    public var isSelectable: Bool {
        !hasAttribute(.noSelect) && !hasAttribute(.nonExistent)
    }

    /// Whether the mailbox has child mailboxes.
    public var hasChildren: Bool {
        hasAttribute(.hasChildren)
    }
}

public extension ImapMailboxListResponse {
    /// Converts this list response to an `ImapMailbox`.
    func toMailbox() -> ImapMailbox {
        ImapMailbox(kind: kind, name: name, delimiter: delimiter, attributes: attributes)
    }
}
