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
// SmtpEnhancedStatusCode.swift
//
// RFC 3463 enhanced status codes.
//

/// Represents an RFC 3463 enhanced SMTP status code.
///
/// Enhanced status codes provide more detailed information about the result of an
/// SMTP command than the basic three-digit status codes. They consist of three
/// parts separated by periods: class.subject.detail (e.g., "2.1.0" or "5.7.1").
///
/// The components are:
/// - **Class**: The first digit indicating success (2), temporary failure (4), or permanent failure (5)
/// - **Subject**: Identifies the general subject of the status (e.g., addressing, mailbox, mail system)
/// - **Detail**: Provides specific detail about the condition
///
/// Enhanced status codes are defined in [RFC 3463](https://tools.ietf.org/html/rfc3463)
/// and are available when the server supports the `ENHANCEDSTATUSCODES` extension.
///
/// ## Example
/// ```swift
/// let response = try transport.send(message)
/// if let enhanced = response.enhancedStatusCode {
///     print("Enhanced status: \(enhanced)")  // e.g., "2.0.0"
/// }
/// ```
///
/// ## See Also
/// - ``SmtpStatusCode``
/// - ``SmtpResponse``
public struct SmtpEnhancedStatusCode: Sendable, Equatable, CustomStringConvertible {
    /// The class component of the enhanced status code.
    ///
    /// Possible values:
    /// - 2: Success
    /// - 4: Persistent transient failure (try again later)
    /// - 5: Permanent failure (do not retry)
    public let klass: Int

    /// The subject component of the enhanced status code.
    ///
    /// Common subjects:
    /// - 0: Other or undefined status
    /// - 1: Addressing status
    /// - 2: Mailbox status
    /// - 3: Mail system status
    /// - 4: Network and routing status
    /// - 5: Mail delivery protocol status
    /// - 6: Message content or media status
    /// - 7: Security or policy status
    public let subject: Int

    /// The detail component of the enhanced status code.
    ///
    /// Provides specific information about the condition within the subject category.
    public let detail: Int

    /// Creates a new enhanced status code with explicit components.
    ///
    /// - Parameters:
    ///   - klass: The class component (2, 4, or 5).
    ///   - subject: The subject component.
    ///   - detail: The detail component.
    public init(klass: Int, subject: Int, detail: Int) {
        self.klass = klass
        self.subject = subject
        self.detail = detail
    }

    /// Creates a new enhanced status code by parsing a string.
    ///
    /// The string must be in the format "X.Y.Z" where X, Y, and Z are integers.
    ///
    /// - Parameter text: The string to parse (e.g., "2.1.0").
    /// - Returns: `nil` if the string is not a valid enhanced status code.
    public init?(_ text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let klass = Int(parts[0]),
              let subject = Int(parts[1]),
              let detail = Int(parts[2]) else {
            return nil
        }
        self.klass = klass
        self.subject = subject
        self.detail = detail
    }

    /// Parses an enhanced status code from the beginning of a response line.
    ///
    /// SMTP servers that support enhanced status codes include them at the
    /// beginning of response text, separated from the rest by whitespace.
    ///
    /// - Parameter line: The response line to parse.
    /// - Returns: The parsed enhanced status code, or `nil` if not found.
    public static func parse(from line: String) -> SmtpEnhancedStatusCode? {
        guard let token = line.split(maxSplits: 1, omittingEmptySubsequences: true, whereSeparator: { $0 == " " || $0 == "\t" }).first else {
            return nil
        }
        return SmtpEnhancedStatusCode(String(token))
    }

    /// A string representation of the enhanced status code in "X.Y.Z" format.
    public var description: String {
        "\(klass).\(subject).\(detail)"
    }
}

public extension SmtpResponse {
    /// All enhanced status codes found in the response lines.
    ///
    /// Each response line may contain an enhanced status code at the beginning.
    /// This property extracts all such codes from all lines.
    var enhancedStatusCodes: [SmtpEnhancedStatusCode] {
        lines.compactMap(SmtpEnhancedStatusCode.parse(from:))
    }

    /// The first enhanced status code found in the response, if any.
    ///
    /// This is typically the most relevant enhanced status code for the response.
    var enhancedStatusCode: SmtpEnhancedStatusCode? {
        enhancedStatusCodes.first
    }
}
