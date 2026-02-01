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

    /// Parses attributes from a FETCH response message that may include literals.
    ///
    /// - Parameter message: The literal message to parse.
    /// - Returns: The parsed attributes, or `nil` if parsing fails.
    public static func parse(_ message: ImapLiteralMessage) -> ImapFetchAttributes? {
        var reader = ImapLineTokenReader(line: message.line, literals: message.literals)
        guard let token = reader.readToken(), token.type == .asterisk else { return nil }
        guard reader.readNumber() != nil else { return nil }
        guard reader.readCaseInsensitiveAtom("FETCH") else { return nil }
        guard let open = reader.readToken(), open.type == .openParen else { return nil }
        return parseAttributeList(reader: &reader)
    }

    /// Parses attributes from a FETCH response payload string.
    ///
    /// - Parameters:
    ///   - payload: The payload string to parse.
    ///   - literals: Optional literal values (in order) referenced by `{n}` markers.
    /// - Returns: The parsed attributes, or `nil` if parsing fails.
    public static func parsePayload(_ payload: String, literals: [[UInt8]]? = nil) -> ImapFetchAttributes? {
        var reader = ImapLineTokenReader(line: payload, literals: literals ?? [])
        guard let token = reader.readToken(), token.type == .openParen else { return nil }
        return parseAttributeList(reader: &reader)
    }

    private static func parseAttributeList(reader: inout ImapLineTokenReader) -> ImapFetchAttributes? {
        var flags: [String] = []
        var uid: UInt32?
        var size: Int?
        var internalDate: String?
        var modSeq: UInt64?
        var envelopeRaw: String?
        var bodyStructure: String?
        var body: String?

        while let token = reader.peekToken() {
            if token.type == .closeParen {
                _ = reader.readToken()
                break
            }
            guard let nameToken = reader.readToken(), nameToken.type == .atom, let name = nameToken.stringValue else {
                return nil
            }
            let upper = name.uppercased()
            switch upper {
            case "FLAGS":
                flags = readFlags(reader: &reader)
            case "UID":
                if let value = reader.readNumber() {
                    uid = UInt32(value)
                }
            case "RFC822.SIZE":
                size = reader.readNumber()
            case "INTERNALDATE":
                internalDate = reader.readNString()
            case "MODSEQ":
                modSeq = readModSeq(reader: &reader)
            case "ENVELOPE":
                envelopeRaw = readStructuredValue(reader: &reader, materializeLiterals: true)
            case "BODYSTRUCTURE":
                bodyStructure = readStructuredValue(reader: &reader, materializeLiterals: true)
            case "BODY", "BODY.PEEK":
                if let peek = reader.peekToken(), peek.type == .openBracket {
                    _ = reader.readBracketedContent(materializeLiterals: true)
                    if let partialToken = reader.peekToken(),
                       partialToken.type == .atom,
                       let partialValue = partialToken.stringValue,
                       partialValue.hasPrefix("<"),
                       partialValue.hasSuffix(">") {
                        _ = reader.readToken()
                    }
                    _ = reader.readToken()
                } else if upper == "BODY" {
                    body = readStructuredValue(reader: &reader, materializeLiterals: true)
                } else {
                    reader.skipValue()
                }
            default:
                reader.skipValue()
            }
        }

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
        guard let envelopeRaw else {
            debugLog("[parsedImapEnvelope] envelopeRaw is nil")
            return nil
        }
        debugLog("[parsedImapEnvelope] envelopeRaw='\(envelopeRaw.prefix(80))...'")
        let result = ImapEnvelope.parse(envelopeRaw)
        if result == nil {
            debugLog("[parsedImapEnvelope] ImapEnvelope.parse returned nil!")
        } else {
            debugLog("[parsedImapEnvelope] parsed successfully, subject='\(result?.subject ?? "nil")'")
        }
        return result
    }

    private func debugLog(_ message: String) {
        MailFoundationLogging.debug(.imapFetch, message)
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

    private static func readFlags(reader: inout ImapLineTokenReader) -> [String] {
        guard let token = reader.readToken(), token.type == .openParen else { return [] }
        var flags: [String] = []
        while let valueToken = reader.readToken() {
            if valueToken.type == .closeParen {
                break
            }
            if let value = valueToken.stringValue {
                flags.append(value)
            }
        }
        return flags
    }

    private static func readModSeq(reader: inout ImapLineTokenReader) -> UInt64? {
        guard let token = reader.readToken(), token.type == .openParen else { return nil }
        let value = reader.readNumber()
        _ = reader.readToken()
        if let value {
            return UInt64(value)
        }
        return nil
    }

    private static func readStructuredValue(reader: inout ImapLineTokenReader, materializeLiterals: Bool) -> String? {
        guard let value = reader.readValueString(materializeLiterals: materializeLiterals) else { return nil }
        if value.uppercased() == "NIL" {
            return nil
        }
        return value
    }
}
