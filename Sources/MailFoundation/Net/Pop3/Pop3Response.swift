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
// Pop3Response.swift
//
// Basic POP3 response model.
//

import Foundation

/// The status of a POP3 response.
///
/// POP3 responses begin with a status indicator:
/// - `+OK` indicates success
/// - `-ERR` indicates an error
/// - `+` (without OK) indicates a continuation for SASL authentication
public enum Pop3ResponseStatus: Sendable {
    /// The command succeeded (`+OK`).
    case ok

    /// The command failed (`-ERR`).
    case err

    /// The server is requesting more data for SASL authentication (`+`).
    case continuation
}

/// Represents a single-line response from a POP3 server.
///
/// POP3 responses consist of a status indicator followed by optional text.
/// This struct parses and provides access to both parts.
///
/// ## Response Format
///
/// POP3 responses follow this format:
/// ```
/// +OK [message text]
/// -ERR [error message]
/// + [SASL challenge data]
/// ```
///
/// ## Usage
///
/// ```swift
/// let response = Pop3Response.parse("+OK Welcome to the server")
/// if response?.isSuccess == true {
///     print("Server says: \(response!.message)")
/// }
///
/// // Check for APOP challenge in greeting
/// if let challenge = response?.apopChallenge {
///     print("Server supports APOP with timestamp: \(challenge)")
/// }
/// ```
///
/// ## See Also
///
/// - ``Pop3ResponseStatus`` for status values
/// - ``Pop3ResponseEvent`` for multiline responses
public struct Pop3Response: Sendable, Equatable {
    /// The status of the response.
    public let status: Pop3ResponseStatus

    /// The message text following the status indicator.
    ///
    /// For `+OK` and `-ERR` responses, this is the text after the status.
    /// For continuation responses, this is the SASL challenge data.
    public let message: String

    /// Whether the response indicates success.
    ///
    /// Returns `true` if the status is `.ok`.
    public var isSuccess: Bool {
        status == .ok
    }

    /// Whether the response is a SASL continuation request.
    ///
    /// Returns `true` if the status is `.continuation`.
    public var isContinuation: Bool {
        status == .continuation
    }

    /// Extracts the APOP challenge timestamp from a greeting response.
    ///
    /// POP3 servers that support APOP authentication include a timestamp
    /// in the greeting response, enclosed in angle brackets.
    ///
    /// - Returns: The timestamp string (including brackets), or nil if not present.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Greeting: +OK POP3 server ready <1234.5678@example.com>
    /// let greeting = try store.connect()
    /// if let challenge = greeting.apopChallenge {
    ///     // challenge is "<1234.5678@example.com>"
    ///     let digest = Pop3Apop.digest(challenge: challenge, password: "secret")
    /// }
    /// ```
    public var apopChallenge: String? {
        guard status == .ok else { return nil }
        guard let start = message.firstIndex(of: "<"),
              let end = message[start...].firstIndex(of: ">"),
              start < end else {
            return nil
        }
        return String(message[start...end])
    }

    /// Parses a POP3 response line.
    ///
    /// - Parameter line: The response line to parse.
    /// - Returns: The parsed response, or nil if the line is not a valid POP3 response.
    public static func parse(_ line: String) -> Pop3Response? {
        if line.hasPrefix("+OK") {
            let message = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
            return Pop3Response(status: .ok, message: String(message))
        }
        if line.hasPrefix("-ERR") {
            let message = line.dropFirst(4).trimmingCharacters(in: .whitespaces)
            return Pop3Response(status: .err, message: String(message))
        }
        if line.hasPrefix("+") {
            let message = line.dropFirst(1).trimmingCharacters(in: .whitespaces)
            return Pop3Response(status: .continuation, message: String(message))
        }
        return nil
    }
}
