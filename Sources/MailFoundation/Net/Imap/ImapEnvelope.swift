//
// ImapEnvelope.swift
//
// Strongly typed IMAP ENVELOPE model.
//

import Foundation
import MimeFoundation

/// Represents the envelope information of an IMAP message.
///
/// The envelope contains the parsed header information from a message,
/// including addresses, date, subject, and message IDs. This corresponds
/// to the ENVELOPE FETCH data item.
///
/// ## Overview
///
/// The envelope provides quick access to commonly needed header fields
/// without parsing the full message headers. It's particularly useful
/// for displaying message lists and threading conversations.
///
/// ## Usage Example
///
/// ```swift
/// let attributes = ImapFetchAttributes.parse(fetchResponse)
/// if let envelope = attributes?.parsedImapEnvelope() {
///     print("Subject: \(envelope.subject ?? "(no subject)")")
///     print("From: \(envelope.from.first?.address ?? "unknown")")
///     if let date = envelope.date {
///         print("Date: \(date)")
///     }
/// }
/// ```
///
/// ## See Also
///
/// - ``ImapFetchAttributes``
/// - ``ImapAddress``
/// - ``ImapMailboxAddress``
public struct ImapEnvelope: Sendable, Equatable {
    /// The Date header value.
    public let date: Date?

    /// The Subject header value.
    public let subject: String?

    /// The From header addresses.
    public let from: [ImapAddress]

    /// The Sender header addresses.
    ///
    /// If not present in the message, this typically mirrors the From addresses.
    public let sender: [ImapAddress]

    /// The Reply-To header addresses.
    ///
    /// If not present in the message, this typically mirrors the From addresses.
    public let replyTo: [ImapAddress]

    /// The To header addresses.
    public let to: [ImapAddress]

    /// The Cc header addresses.
    public let cc: [ImapAddress]

    /// The Bcc header addresses.
    ///
    /// Note: Bcc headers are typically only visible when fetching your own sent messages.
    public let bcc: [ImapAddress]

    /// The In-Reply-To header value.
    ///
    /// Contains the Message-ID of the message being replied to.
    public let inReplyTo: String?

    /// The Message-ID header value.
    ///
    /// A unique identifier for this message.
    public let messageId: String?

    /// Creates a new envelope with the specified values.
    ///
    /// - Parameters:
    ///   - date: The Date header value.
    ///   - subject: The Subject header value.
    ///   - from: The From addresses.
    ///   - sender: The Sender addresses.
    ///   - replyTo: The Reply-To addresses.
    ///   - to: The To addresses.
    ///   - cc: The Cc addresses.
    ///   - bcc: The Bcc addresses.
    ///   - inReplyTo: The In-Reply-To header value.
    ///   - messageId: The Message-ID header value.
    public init(
        date: Date?,
        subject: String?,
        from: [ImapAddress],
        sender: [ImapAddress],
        replyTo: [ImapAddress],
        to: [ImapAddress],
        cc: [ImapAddress],
        bcc: [ImapAddress],
        inReplyTo: String?,
        messageId: String?
    ) {
        self.date = date
        self.subject = subject
        self.from = from
        self.sender = sender
        self.replyTo = replyTo
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.inReplyTo = inReplyTo
        self.messageId = messageId
    }

    /// Parses an envelope from its IMAP string representation.
    ///
    /// - Parameter text: The ENVELOPE string from a FETCH response.
    /// - Returns: The parsed envelope, or `nil` if parsing fails.
    public static func parse(_ text: String) -> ImapEnvelope? {
        guard let envelope = try? Envelope(parsing: text) else { return nil }
        return ImapEnvelope(envelope: envelope)
    }

    public init(envelope: Envelope) {
        self.date = envelope.date
        self.subject = envelope.subject
        self.from = ImapEnvelope.convert(envelope.from)
        self.sender = ImapEnvelope.convert(envelope.sender)
        self.replyTo = ImapEnvelope.convert(envelope.replyTo)
        self.to = ImapEnvelope.convert(envelope.to)
        self.cc = ImapEnvelope.convert(envelope.cc)
        self.bcc = ImapEnvelope.convert(envelope.bcc)
        self.inReplyTo = envelope.inReplyTo
        self.messageId = envelope.messageId
    }

    private static func convert(_ list: InternetAddressList) -> [ImapAddress] {
        var result: [ImapAddress] = []
        for address in list {
            if let mailbox = address as? MailboxAddress {
                result.append(.mailbox(ImapMailboxAddress(mailbox: mailbox)))
            } else if let group = address as? GroupAddress {
                let members = group.members.compactMap { member in
                    (member as? MailboxAddress).map(ImapMailboxAddress.init)
                }
                result.append(.group(ImapGroupAddress(name: group.name, members: members)))
            }
        }
        return result
    }
}

/// Represents an address in an IMAP envelope.
///
/// IMAP addresses can be either individual mailboxes or groups of addresses.
/// Most commonly, you'll encounter mailbox addresses for individual recipients.
///
/// ## See Also
///
/// - ``ImapMailboxAddress``
/// - ``ImapGroupAddress``
public enum ImapAddress: Sendable, Equatable {
    /// An individual mailbox address.
    case mailbox(ImapMailboxAddress)

    /// A group of addresses with a display name.
    case group(ImapGroupAddress)
}

/// Represents an individual mailbox (email) address in an IMAP envelope.
///
/// A mailbox address consists of a display name, optional routing information,
/// and the actual email address (mailbox@host).
///
/// ## Properties
///
/// - `name` - The display name (e.g., "John Doe")
/// - `mailbox` - The local part of the address (before @)
/// - `host` - The domain part of the address (after @)
/// - `address` - The full email address (mailbox@host)
///
/// ## Example
///
/// ```swift
/// if case .mailbox(let addr) = envelope.from.first {
///     if let name = addr.name {
///         print("From: \(name) <\(addr.address ?? "")>")
///     } else {
///         print("From: \(addr.address ?? "")")
///     }
/// }
/// ```
public struct ImapMailboxAddress: Sendable, Equatable {
    /// The display name associated with the address.
    public let name: String?

    /// The source routing information (rarely used in modern email).
    public let route: String?

    /// The local part of the email address (before the @).
    public let mailbox: String?

    /// The domain part of the email address (after the @).
    public let host: String?

    /// Creates a new mailbox address with the specified components.
    ///
    /// - Parameters:
    ///   - name: The display name.
    ///   - route: The source route (typically nil).
    ///   - mailbox: The local part of the address.
    ///   - host: The domain part of the address.
    public init(name: String?, route: String?, mailbox: String?, host: String?) {
        self.name = name
        self.route = route
        self.mailbox = mailbox
        self.host = host
    }

    /// Creates a mailbox address from a MimeFoundation MailboxAddress.
    ///
    /// - Parameter mailbox: The source mailbox address.
    public init(mailbox: MailboxAddress) {
        self.name = mailbox.name
        self.route = mailbox.route.isEmpty ? nil : mailbox.route.description
        if let atIndex = mailbox.address.firstIndex(of: "@") {
            let user = String(mailbox.address[..<atIndex])
            let host = String(mailbox.address[mailbox.address.index(after: atIndex)...])
            self.mailbox = user.isEmpty ? nil : user
            self.host = host.isEmpty ? nil : host
        } else {
            self.mailbox = mailbox.address.isEmpty ? nil : mailbox.address
            self.host = nil
        }
    }

    /// The full email address (mailbox@host).
    ///
    /// Returns nil if the mailbox component is not set.
    public var address: String? {
        guard let mailbox else { return nil }
        if let host {
            return "\(mailbox)@\(host)"
        }
        return mailbox
    }
}

/// Represents a group address in an IMAP envelope.
///
/// Group addresses are used to represent named groups of recipients,
/// such as distribution lists. They consist of a group name and a list
/// of member mailbox addresses.
///
/// ## Example
///
/// A group address might represent: `Team: alice@example.com, bob@example.com;`
public struct ImapGroupAddress: Sendable, Equatable {
    /// The name of the group.
    public let name: String?

    /// The member addresses in the group.
    public let members: [ImapMailboxAddress]
}
