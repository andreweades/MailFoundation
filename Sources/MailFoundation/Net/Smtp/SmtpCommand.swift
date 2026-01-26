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
// SmtpCommand.swift
//
// Basic SMTP command model.
//

/// Represents an SMTP command to be sent to an SMTP server.
///
/// SMTP commands consist of a keyword (verb) and optional arguments,
/// terminated by CRLF. This type provides a structured way to create
/// and serialize SMTP commands.
///
/// ## Example
/// ```swift
/// // Create a simple command
/// let noop = SmtpCommand(keyword: "NOOP")
///
/// // Create a command with arguments
/// let ehlo = SmtpCommand(keyword: "EHLO", arguments: "example.com")
///
/// // Get the serialized form ready to send
/// let bytes = Array(ehlo.serialized.utf8)  // "EHLO example.com\r\n"
/// ```
///
/// For common SMTP commands, consider using ``SmtpCommandKind`` which provides
/// type-safe command construction.
///
/// ## See Also
/// - ``SmtpCommandKind``
/// - ``SmtpResponse``
public struct SmtpCommand: Sendable {
    /// The command keyword (verb).
    ///
    /// Common SMTP keywords include: HELO, EHLO, MAIL, RCPT, DATA, QUIT, RSET, NOOP, VRFY, EXPN, HELP.
    public let keyword: String

    /// The command arguments, if any.
    ///
    /// For example, for `EHLO example.com`, the arguments would be `"example.com"`.
    /// For `MAIL FROM:<user@example.com>`, the arguments would be `"FROM:<user@example.com>"`.
    public let arguments: String?

    /// Creates a new SMTP command.
    ///
    /// - Parameters:
    ///   - keyword: The command keyword (e.g., "EHLO", "MAIL", "RCPT").
    ///   - arguments: Optional arguments for the command.
    public init(keyword: String, arguments: String? = nil) {
        self.keyword = keyword
        self.arguments = arguments
    }

    /// The serialized command string ready to be sent to the server.
    ///
    /// The format is `"KEYWORD ARGUMENTS\r\n"` if arguments are present,
    /// or `"KEYWORD\r\n"` if there are no arguments.
    public var serialized: String {
        if let arguments {
            return "\(keyword) \(arguments)\r\n"
        }
        return "\(keyword)\r\n"
    }
}
