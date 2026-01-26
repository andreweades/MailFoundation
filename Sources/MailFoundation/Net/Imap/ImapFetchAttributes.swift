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
// ImapFetchAttributes.swift
//
// Parse common IMAP FETCH attributes from a FETCH response payload.
//

import Foundation

/// Contains parsed attributes from an IMAP FETCH response.
///
/// `ImapFetchAttributes` provides access to the various data items that can be
/// requested in a FETCH command, including flags, UID, size, envelope, and
/// body structure.
///
/// ## Overview
///
/// When you fetch messages, the server returns various attributes based on
/// your request. This type parses those attributes into a convenient structure.
///
/// ## Usage Example
///
/// ```swift
/// let response = try session.fetch("1:10", items: ["FLAGS", "UID", "ENVELOPE"])
/// for fetch in response.fetches {
///     if let attrs = ImapFetchAttributes.parse(fetch) {
///         print("UID: \(attrs.uid ?? 0)")
///         print("Flags: \(attrs.flags.joined(separator: ", "))")
///         if let envelope = attrs.parsedImapEnvelope() {
///             print("Subject: \(envelope.subject ?? "")")
///         }
///     }
/// }
/// ```
///
/// ## Available Attributes
///
/// - `flags` - Message flags (\Seen, \Answered, etc.)
/// - `uid` - The message's unique identifier
/// - `size` - The RFC822.SIZE value
/// - `internalDate` - The server's internal date
/// - `modSeq` - The modification sequence (CONDSTORE)
/// - `envelopeRaw` - The raw ENVELOPE data
/// - `bodyStructure` - The raw BODYSTRUCTURE data
///
/// ## See Also
///
/// - ``ImapEnvelope``
/// - ``ImapBodyStructure``
/// - ``ImapFetchResponse``
public struct ImapFetchAttributes: Sendable, Equatable {
    /// The message flags (e.g., "\Seen", "\Answered", "\Flagged").
    public let flags: [String]

    /// The message's unique identifier.
    public let uid: UInt32?

    /// The message size in bytes (RFC822.SIZE).
    public let size: Int?

    /// The server's internal date for the message.
    public let internalDate: String?

    /// The modification sequence number (for CONDSTORE).
    public let modSeq: UInt64?

    /// The raw ENVELOPE data as a string.
    public let envelopeRaw: String?

    /// The raw BODYSTRUCTURE data as a string.
    public let bodyStructure: String?

    /// The raw BODY data as a string (if BODY was fetched).
    public let body: String?

    /// Creates a new fetch attributes instance.
    ///
    /// - Parameters:
    ///   - flags: The message flags.
    ///   - uid: The message UID.
    ///   - size: The message size.
    ///   - internalDate: The internal date.
    ///   - modSeq: The modification sequence.
    ///   - envelopeRaw: The raw envelope data.
    ///   - bodyStructure: The raw body structure data.
    ///   - body: The raw body data.
    public init(
        flags: [String] = [],
        uid: UInt32? = nil,
        size: Int? = nil,
        internalDate: String? = nil,
        modSeq: UInt64? = nil,
        envelopeRaw: String? = nil,
        bodyStructure: String? = nil,
        body: String? = nil
    ) {
        self.flags = flags
        self.uid = uid
        self.size = size
        self.internalDate = internalDate
        self.modSeq = modSeq
        self.envelopeRaw = envelopeRaw
        self.bodyStructure = bodyStructure
        self.body = body
    }

    /// Parses attributes from a FETCH response.
    ///
    /// - Parameter fetch: The FETCH response to parse.
    /// - Returns: The parsed attributes, or `nil` if parsing fails.
    public static func parse(_ fetch: ImapFetchResponse) -> ImapFetchAttributes? {
        parsePayload(fetch.payload)
    }

    /// Parses attributes from a FETCH response payload string.
    ///
    /// - Parameter payload: The payload string to parse.
    /// - Returns: The parsed attributes, or `nil` if parsing fails.
    public static func parsePayload(_ payload: String) -> ImapFetchAttributes? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("("), trimmed.hasSuffix(")") else {
            return nil
        }

        let contentStart = trimmed.index(after: trimmed.startIndex)
        let contentEnd = trimmed.index(before: trimmed.endIndex)
        let content = String(trimmed[contentStart..<contentEnd])
        let attributes = parseAttributes(content)

        let flags = parseFlags(attributes["FLAGS"])
        let uid = parseUInt32(attributes["UID"])
        let size = parseInt(attributes["RFC822.SIZE"])
        let internalDate = attributes["INTERNALDATE"]
        let modSeq = parseUInt64(attributes["MODSEQ"])
        let envelopeRaw = attributes["ENVELOPE"]
        let bodyStructure = attributes["BODYSTRUCTURE"]
        let body = attributes["BODY"]

        return ImapFetchAttributes(
            flags: flags,
            uid: uid,
            size: size,
            internalDate: internalDate,
            modSeq: modSeq,
            envelopeRaw: envelopeRaw,
            bodyStructure: bodyStructure,
            body: body
        )
    }

    /// Parses the envelope as a MimeFoundation `Envelope`.
    ///
    /// - Returns: The parsed envelope, or `nil` if not available or parsing fails.
    public func parsedEnvelope() -> Envelope? {
        guard let envelopeRaw else { return nil }
        return try? Envelope(parsing: envelopeRaw)
    }

    /// Parses the envelope as an `ImapEnvelope`.
    ///
    /// - Returns: The parsed IMAP envelope, or `nil` if not available or parsing fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let envelope = attributes.parsedImapEnvelope() {
    ///     print("From: \(envelope.from.first?.address ?? "unknown")")
    ///     print("Subject: \(envelope.subject ?? "")")
    /// }
    /// ```
    public func parsedImapEnvelope() -> ImapEnvelope? {
        guard let envelopeRaw else { return nil }
        return ImapEnvelope.parse(envelopeRaw)
    }

    /// Parses the envelope using a cache for performance.
    ///
    /// When parsing many envelopes, using a cache can improve performance
    /// by reusing previously parsed results.
    ///
    /// - Parameter cache: The envelope cache to use.
    /// - Returns: The parsed IMAP envelope, or `nil` if not available or parsing fails.
    public func parsedImapEnvelope(using cache: ImapEnvelopeCache) async -> ImapEnvelope? {
        guard let envelopeRaw else { return nil }
        return await cache.envelope(for: envelopeRaw)
    }

    /// Parses the body structure.
    ///
    /// - Returns: The parsed body structure, or `nil` if not available or parsing fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let structure = attributes.parsedBodyStructure() {
    ///     for (id, part) in structure.enumerateParts() {
    ///         print("Part \(id): \(part.type)/\(part.subtype)")
    ///     }
    /// }
    /// ```
    public func parsedBodyStructure() -> ImapBodyStructure? {
        guard let bodyStructure else { return nil }
        return ImapBodyStructure.parse(bodyStructure)
    }

    private static func parseAttributes(_ content: String) -> [String: String] {
        var attributes: [String: String] = [:]
        var index = content.startIndex

        func skipWhitespace() {
            while index < content.endIndex, content[index].isWhitespace {
                index = content.index(after: index)
            }
        }

        func readAtom() -> String? {
            skipWhitespace()
            guard index < content.endIndex else { return nil }
            let start = index
            while index < content.endIndex {
                let ch = content[index]
                if ch.isWhitespace || ch == "(" || ch == ")" || ch == "\"" {
                    break
                }
                index = content.index(after: index)
            }
            guard start < index else { return nil }
            return String(content[start..<index])
        }

        func readQuoted() -> String? {
            guard index < content.endIndex, content[index] == "\"" else { return nil }
            index = content.index(after: index)
            var result = ""
            var escape = false
            while index < content.endIndex {
                let ch = content[index]
                if escape {
                    result.append(ch)
                    escape = false
                } else if ch == "\\" {
                    escape = true
                } else if ch == "\"" {
                    index = content.index(after: index)
                    return result
                } else {
                    result.append(ch)
                }
                index = content.index(after: index)
            }
            return nil
        }

        func readParenthesized() -> String? {
            guard index < content.endIndex, content[index] == "(" else { return nil }
            var depth = 0
            var inQuote = false
            var escape = false
            let start = index
            while index < content.endIndex {
                let ch = content[index]
                if inQuote {
                    if escape {
                        escape = false
                    } else if ch == "\\" {
                        escape = true
                    } else if ch == "\"" {
                        inQuote = false
                    }
                } else {
                    if ch == "\"" {
                        inQuote = true
                    } else if ch == "(" {
                        depth += 1
                    } else if ch == ")" {
                        depth -= 1
                        if depth == 0 {
                            let end = content.index(after: index)
                            index = end
                            return String(content[start..<end])
                        }
                    }
                }
                index = content.index(after: index)
            }
            return nil
        }

        func readValue() -> String? {
            skipWhitespace()
            guard index < content.endIndex else { return nil }
            let ch = content[index]
            if ch == "\"" {
                return readQuoted()
            }
            if ch == "(" {
                return readParenthesized()
            }
            return readAtom()
        }

        while let name = readAtom() {
            let value = readValue()
            if let value {
                attributes[name.uppercased()] = value
            }
        }

        return attributes
    }

    private static func parseFlags(_ value: String?) -> [String] {
        guard let value else { return [] }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("("), trimmed.hasSuffix(")") else { return [] }
        let start = trimmed.index(after: trimmed.startIndex)
        let end = trimmed.index(before: trimmed.endIndex)
        let inner = trimmed[start..<end]
        return inner.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    }

    private static func parseInt(_ value: String?) -> Int? {
        guard let value else { return nil }
        return Int(value)
    }

    private static func parseUInt32(_ value: String?) -> UInt32? {
        guard let value else { return nil }
        return UInt32(value)
    }

    private static func parseUInt64(_ value: String?) -> UInt64? {
        guard let value else { return nil }
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("("), trimmed.hasSuffix(")") {
            trimmed.removeFirst()
            trimmed.removeLast()
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return UInt64(trimmed)
    }
}
