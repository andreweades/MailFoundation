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
// Pop3Command.swift
//
// Basic POP3 command model.
//

/// Represents a POP3 command ready to be sent to the server.
///
/// A POP3 command consists of a keyword (like USER, PASS, STAT) and optional
/// arguments. This struct handles serialization to the wire format.
///
/// ## Command Format
///
/// POP3 commands follow this format:
/// ```
/// KEYWORD [arguments]\r\n
/// ```
///
/// ## Usage
///
/// For most use cases, use ``Pop3CommandKind`` to create commands:
///
/// ```swift
/// let command = Pop3CommandKind.user("username").command()
/// print(command.serialized)  // "USER username\r\n"
/// ```
///
/// Or create commands directly:
///
/// ```swift
/// let command = Pop3Command(keyword: "NOOP")
/// let retr = Pop3Command(keyword: "RETR", arguments: "1")
/// ```
///
/// ## See Also
///
/// - ``Pop3CommandKind`` for type-safe command construction
/// - ``Pop3Client/send(_:)`` for sending commands
public struct Pop3Command: Sendable {
    /// The command keyword (e.g., "USER", "PASS", "STAT").
    public let keyword: String

    /// Optional arguments for the command.
    public let arguments: String?

    /// Initializes a new POP3 command.
    ///
    /// - Parameters:
    ///   - keyword: The command keyword.
    ///   - arguments: Optional arguments for the command.
    public init(keyword: String, arguments: String? = nil) {
        self.keyword = keyword
        self.arguments = arguments
    }

    /// The command serialized for transmission.
    ///
    /// Returns the command in wire format, terminated with CRLF.
    public var serialized: String {
        if let arguments {
            return "\(keyword) \(arguments)\r\n"
        }
        return "\(keyword)\r\n"
    }
}
