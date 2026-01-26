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
// ImapCapabilities.swift
//
// IMAP capability parsing.
//

import Foundation

/// Represents the capabilities advertised by an IMAP server.
///
/// IMAP servers advertise their capabilities in response to the CAPABILITY command
/// and in the greeting response. Capabilities indicate which extensions and features
/// the server supports.
///
/// ## Overview
///
/// Common capabilities include:
/// - `IMAP4rev1` - Basic IMAP protocol support
/// - `IDLE` - Real-time notifications (RFC 2177)
/// - `UIDPLUS` - Unique ID extensions (RFC 4315)
/// - `MOVE` - Atomic move operation (RFC 6851)
/// - `CONDSTORE` - Conditional STORE (RFC 7162)
/// - `QRESYNC` - Quick resynchronization (RFC 7162)
/// - `SORT` - Server-side sorting (RFC 5256)
///
/// ## Usage Example
///
/// ```swift
/// if let caps = store.capabilities {
///     if caps.supports("IDLE") {
///         // Server supports IDLE for push notifications
///     }
///     if caps.supports("MOVE") {
///         // Can use MOVE instead of COPY+DELETE
///     }
/// }
/// ```
///
/// ## See Also
///
/// - ``ImapMailStore``
/// - ``ImapSession``
public struct ImapCapabilities: Sendable, Equatable {
    /// The raw capability tokens as received from the server.
    public let rawTokens: [String]

    /// The set of capabilities in uppercase for case-insensitive lookup.
    public let capabilities: Set<String>

    /// Creates a new capabilities instance from the given tokens.
    ///
    /// - Parameter tokens: The capability tokens from the server response.
    public init(tokens: [String]) {
        self.rawTokens = tokens
        self.capabilities = Set(tokens.map { $0.uppercased() })
    }

    /// Checks if the server supports a specific capability.
    ///
    /// The comparison is case-insensitive.
    ///
    /// - Parameter name: The capability name to check (e.g., "IDLE", "MOVE").
    /// - Returns: `true` if the capability is supported, `false` otherwise.
    public func supports(_ name: String) -> Bool {
        capabilities.contains(name.uppercased())
    }

    /// Parses capabilities from an IMAP response line.
    ///
    /// This method can parse capabilities from both untagged CAPABILITY responses
    /// and bracketed capability lists in greeting/OK responses.
    ///
    /// - Parameter line: The response line to parse.
    /// - Returns: The parsed capabilities, or `nil` if parsing fails.
    public static func parse(from line: String) -> ImapCapabilities? {
        if let bracketed = parseBracketedCapabilities(from: line) {
            return bracketed
        }

        let tokens = line.split(separator: " ").map(String.init)
        guard let index = tokens.firstIndex(where: { $0.caseInsensitiveEquals("CAPABILITY") }) else {
            return nil
        }
        let capabilityTokens = tokens[(index + 1)...]
        guard !capabilityTokens.isEmpty else { return nil }
        return ImapCapabilities(tokens: Array(capabilityTokens))
    }

    private static func parseBracketedCapabilities(from line: String) -> ImapCapabilities? {
        guard let range = line.range(of: "[CAPABILITY", options: [.caseInsensitive]) else {
            return nil
        }

        let after = line[range.upperBound...]
        guard let end = after.firstIndex(of: "]") else {
            return nil
        }

        let contents = after[..<end]
        let tokens = contents.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return nil }
        return ImapCapabilities(tokens: tokens)
    }
}

private extension String {
    func caseInsensitiveEquals(_ other: String) -> Bool {
        compare(other, options: [.caseInsensitive]) == .orderedSame
    }
}
