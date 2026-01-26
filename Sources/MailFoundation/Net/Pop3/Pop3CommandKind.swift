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
// Pop3CommandKind.swift
//
// POP3 command definitions.
//

/// A type-safe representation of POP3 commands.
///
/// `Pop3CommandKind` provides a Swift-native way to construct POP3 commands
/// with proper parameter types. Each case corresponds to a standard POP3 command.
///
/// ## Standard Commands
///
/// The following commands are defined by RFC 1939:
/// - ``user(_:)`` - Identifies the user for authentication
/// - ``pass(_:)`` - Provides the password for authentication
/// - ``stat`` - Gets message count and total size
/// - ``list(_:)`` - Gets message sizes
/// - ``retr(_:)`` - Retrieves a message
/// - ``dele(_:)`` - Marks a message for deletion
/// - ``noop`` - No operation (keep-alive)
/// - ``rset`` - Resets deletion marks
/// - ``quit`` - Ends the session
///
/// ## Extension Commands
///
/// The following commands are defined by POP3 extensions:
/// - ``uidl(_:)`` - Gets unique message identifiers (RFC 1939)
/// - ``top(_:lines:)`` - Gets message headers and partial body (RFC 1939)
/// - ``capa`` - Queries server capabilities (RFC 2449)
/// - ``stls`` - Starts TLS encryption (RFC 2595)
/// - ``apop(_:_:)`` - APOP authentication (RFC 1939)
/// - ``auth(_:initialResponse:)`` - SASL authentication (RFC 5034)
/// - ``last`` - Gets highest accessed message number (obsolete)
///
/// ## Usage
///
/// ```swift
/// // Create and send commands
/// let userCmd = Pop3CommandKind.user("alice@example.com")
/// let passCmd = Pop3CommandKind.pass("secret")
/// let statCmd = Pop3CommandKind.stat
/// let retrCmd = Pop3CommandKind.retr(1)
///
/// // Convert to Pop3Command for serialization
/// let command = userCmd.command()
/// print(command.serialized)  // "USER alice@example.com\r\n"
/// ```
///
/// ## See Also
///
/// - ``Pop3Command`` for the serializable command type
/// - ``Pop3Client/send(_:)-swift.method`` for sending commands
public enum Pop3CommandKind: Sendable {
    /// Identifies the user for USER/PASS authentication.
    ///
    /// - Parameter name: The username or email address.
    case user(String)

    /// Provides the password for USER/PASS authentication.
    ///
    /// - Parameter password: The user's password.
    case pass(String)

    /// Gets the message count and total size of the mailbox.
    ///
    /// The server responds with: `+OK nn mm` where nn is the count and mm is the total size.
    case stat

    /// Gets message sizes.
    ///
    /// - Parameter index: If specified, gets the size of a single message. If nil, lists all messages.
    case list(Int?)

    /// Retrieves a complete message.
    ///
    /// - Parameter index: The 1-based message index.
    case retr(Int)

    /// Marks a message for deletion.
    ///
    /// The message is not actually deleted until QUIT is sent.
    ///
    /// - Parameter index: The 1-based message index.
    case dele(Int)

    /// No operation - used to keep the connection alive.
    case noop

    /// Resets the session, unmarking any messages marked for deletion.
    case rset

    /// Ends the session and commits any deletions.
    case quit

    /// Gets unique message identifiers.
    ///
    /// - Parameter index: If specified, gets the UID of a single message. If nil, lists all UIDs.
    case uidl(Int?)

    /// Gets message headers and a partial body.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    case top(Int, lines: Int)

    /// Queries server capabilities.
    case capa

    /// Requests STARTTLS encryption.
    case stls

    /// APOP authentication with a pre-computed digest.
    ///
    /// - Parameters:
    ///   - user: The username.
    ///   - digest: The MD5 digest of the timestamp and password.
    case apop(String, String)

    /// SASL authentication.
    ///
    /// - Parameters:
    ///   - mechanism: The SASL mechanism name (e.g., "PLAIN", "LOGIN", "CRAM-MD5").
    ///   - initialResponse: Optional initial response data (base64 encoded).
    case auth(String, initialResponse: String?)

    /// Gets the highest message number accessed in this session.
    ///
    /// This is an obsolete command that may not be supported by all servers.
    case last

    /// Converts this command kind to a ``Pop3Command`` ready for serialization.
    ///
    /// - Returns: A ``Pop3Command`` with the appropriate keyword and arguments.
    public func command() -> Pop3Command {
        switch self {
        case let .user(name):
            return Pop3Command(keyword: "USER", arguments: name)
        case let .pass(password):
            return Pop3Command(keyword: "PASS", arguments: password)
        case .stat:
            return Pop3Command(keyword: "STAT")
        case let .list(index):
            if let index {
                return Pop3Command(keyword: "LIST", arguments: "\(index)")
            }
            return Pop3Command(keyword: "LIST")
        case let .retr(index):
            return Pop3Command(keyword: "RETR", arguments: "\(index)")
        case let .dele(index):
            return Pop3Command(keyword: "DELE", arguments: "\(index)")
        case .noop:
            return Pop3Command(keyword: "NOOP")
        case .rset:
            return Pop3Command(keyword: "RSET")
        case .quit:
            return Pop3Command(keyword: "QUIT")
        case let .uidl(index):
            if let index {
                return Pop3Command(keyword: "UIDL", arguments: "\(index)")
            }
            return Pop3Command(keyword: "UIDL")
        case let .top(index, lines):
            return Pop3Command(keyword: "TOP", arguments: "\(index) \(lines)")
        case .capa:
            return Pop3Command(keyword: "CAPA")
        case .stls:
            return Pop3Command(keyword: "STLS")
        case let .apop(user, digest):
            return Pop3Command(keyword: "APOP", arguments: "\(user) \(digest)")
        case let .auth(mechanism, initialResponse):
            if let response = initialResponse {
                return Pop3Command(keyword: "AUTH", arguments: "\(mechanism) \(response)")
            }
            return Pop3Command(keyword: "AUTH", arguments: mechanism)
        case .last:
            return Pop3Command(keyword: "LAST")
        }
    }
}
