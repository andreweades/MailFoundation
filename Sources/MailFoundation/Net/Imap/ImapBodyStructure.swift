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
// ImapBodyStructure.swift
//
// IMAP BODYSTRUCTURE parser (minimal).
//

import Foundation

/// Represents a content disposition header (e.g., "attachment", "inline").
///
/// Content disposition indicates how a body part should be displayed or handled.
///
/// ## Example
///
/// ```swift
/// if let disposition = bodyPart.disposition {
///     if disposition.type.uppercased() == "ATTACHMENT" {
///         let filename = disposition.parameters["FILENAME"]
///         // Handle attachment
///     }
/// }
/// ```
public struct ImapContentDisposition: Sendable, Equatable {
    /// The disposition type (e.g., "inline", "attachment").
    public let type: String

    /// The disposition parameters (e.g., "filename", "size").
    public let parameters: [String: String]
}

/// Represents a single (non-multipart) body part in an IMAP message.
///
/// A body part contains information about the content type, encoding, size,
/// and other metadata for a single MIME part.
///
/// ## Properties
///
/// - `type` and `subtype` together form the content type (e.g., "TEXT/PLAIN")
/// - `encoding` is the content transfer encoding (e.g., "BASE64", "QUOTED-PRINTABLE")
/// - `size` is the body size in bytes
/// - `lines` is the number of lines (for TEXT types)
///
/// ## See Also
///
/// - ``ImapBodyStructure``
/// - ``ImapMultipart``
public struct ImapBodyPart: Sendable, Equatable {
    /// The MIME type (e.g., "TEXT", "IMAGE", "APPLICATION").
    public let type: String

    /// The MIME subtype (e.g., "PLAIN", "HTML", "PDF").
    public let subtype: String

    /// The content type parameters (e.g., "CHARSET", "NAME").
    public let parameters: [String: String]

    /// The Content-ID header value.
    public let id: String?

    /// The Content-Description header value.
    public let description: String?

    /// The content transfer encoding (e.g., "7BIT", "BASE64", "QUOTED-PRINTABLE").
    public let encoding: String?

    /// The body size in bytes.
    public let size: Int?

    /// The number of lines (for TEXT types).
    public let lines: Int?

    /// The MD5 checksum of the body, if provided.
    public let md5: String?

    /// The raw envelope data for embedded MESSAGE/RFC822 parts.
    public let envelopeRaw: String?

    /// The embedded body structure for MESSAGE/RFC822 parts.
    public let embedded: ImapBodyStructure?

    /// The content disposition (inline, attachment).
    public let disposition: ImapContentDisposition?

    /// The content language(s).
    public let language: [String]?

    /// The content location URI.
    public let location: String?

    /// Additional extension data.
    public let extensions: [String]
}

/// Represents a multipart body structure containing multiple parts.
///
/// Multipart messages contain multiple body parts, such as text and HTML
/// alternatives, or a message body with attachments.
///
/// ## Common Subtypes
///
/// - `MIXED` - Different content types (typical for attachments)
/// - `ALTERNATIVE` - Same content in different formats (text/html)
/// - `RELATED` - Related content (HTML with inline images)
/// - `SIGNED` - Digitally signed content
/// - `ENCRYPTED` - Encrypted content
///
/// ## See Also
///
/// - ``ImapBodyStructure``
/// - ``ImapBodyPart``
public struct ImapMultipart: Sendable, Equatable {
    /// The child parts of this multipart.
    public let parts: [ImapBodyStructure]

    /// The multipart subtype (e.g., "MIXED", "ALTERNATIVE", "RELATED").
    public let subtype: String

    /// The multipart parameters (e.g., "BOUNDARY").
    public let parameters: [String: String]

    /// The content disposition, if any.
    public let disposition: ImapContentDisposition?

    /// The content language(s).
    public let language: [String]?

    /// The content location URI.
    public let location: String?

    /// Additional extension data.
    public let extensions: [String]
}

/// Represents the structure of an IMAP message body.
///
/// The body structure describes the MIME structure of a message, including
/// content types, encodings, sizes, and nested parts. This information is
/// returned by the BODYSTRUCTURE FETCH item.
///
/// ## Overview
///
/// IMAP body structures are either single parts (text, image, etc.) or
/// multipart containers. Each part is identified by a section specifier
/// (e.g., "1", "2.1", "2.2").
///
/// ## Usage Example
///
/// ```swift
/// let bodyStructure = attributes.parsedBodyStructure()
///
/// // Enumerate all parts
/// for (id, part) in bodyStructure.enumerateParts() {
///     print("Part \(id): \(part.type)/\(part.subtype)")
///     if let encoding = part.encoding {
///         print("  Encoding: \(encoding)")
///     }
/// }
///
/// // Get a specific part
/// if let textPart = bodyStructure.part(for: "1") {
///     print("Text part: \(textPart.type)/\(textPart.subtype)")
/// }
/// ```
///
/// ## Part Numbering
///
/// IMAP part numbers follow a dot-separated hierarchy:
/// - "1" - First (or only) part
/// - "2" - Second part
/// - "2.1" - First subpart of the second part
/// - "2.1.1" - First subpart of the first subpart of the second part
///
/// ## See Also
///
/// - ``ImapBodyPart``
/// - ``ImapMultipart``
/// - ``ImapFetchAttributes``
public indirect enum ImapBodyStructure: Sendable, Equatable {
    /// A single (non-multipart) body part.
    case single(ImapBodyPart)

    /// A multipart container with child parts.
    case multipart(ImapMultipart)

    /// Parses a body structure from its string representation.
    ///
    /// - Parameter text: The BODYSTRUCTURE string from a FETCH response.
    /// - Returns: The parsed body structure, or `nil` if parsing fails.
    public static func parse(_ text: String) -> ImapBodyStructure? {
        var parser = ImapBodyStructureParser(text: text)
        guard let node = parser.parse() else {
            return nil
        }
        return parseNode(node)
    }

    /// Enumerates all body parts with their section IDs.
    ///
    /// This method traverses the entire body structure and returns all
    /// single (non-multipart) parts with their IMAP section identifiers.
    ///
    /// - Returns: An array of tuples containing (section ID, body part).
    ///
    /// ## Example
    ///
    /// ```swift
    /// for (sectionId, part) in bodyStructure.enumerateParts() {
    ///     print("Section \(sectionId): \(part.type)/\(part.subtype)")
    /// }
    /// ```
    public func enumerateParts() -> [(String, ImapBodyPart)] {
        var result: [(String, ImapBodyPart)] = []
        enumerateParts(prefix: "", into: &result)
        return result
    }

    /// Gets the body structure node at the specified section ID.
    ///
    /// - Parameter id: The section ID (e.g., "1", "2.1").
    /// - Returns: The body structure node, or `nil` if not found.
    public func node(for id: String) -> ImapBodyStructure? {
        guard let path = Self.parsePartPath(id) else { return nil }
        return node(for: path)
    }

    /// Gets the body part at the specified section ID.
    ///
    /// Unlike `node(for:)`, this method only returns single (non-multipart) parts.
    ///
    /// - Parameter id: The section ID (e.g., "1", "2.1").
    /// - Returns: The body part, or `nil` if not found or if it's a multipart.
    public func part(for id: String) -> ImapBodyPart? {
        guard let node = node(for: id) else { return nil }
        if case let .single(part) = node {
            return part
        }
        return nil
    }

    /// Resolves a fetch body section against this structure.
    ///
    /// - Parameter section: The body section to resolve.
    /// - Returns: The resolution result, or `nil` if the section is invalid.
    public func resolve(section: ImapFetchBodySection) -> ImapBodySectionResolution? {
        if section.part.isEmpty {
            return ImapBodySectionResolution(scope: .message(node: self), subsection: section.subsection)
        }
        guard let node = node(for: section.part) else { return nil }
        let id = section.part.map { String($0) }.joined(separator: ".")
        return ImapBodySectionResolution(scope: .part(id: id, node: node), subsection: section.subsection)
    }

    private func enumerateParts(prefix: String, into result: inout [(String, ImapBodyPart)]) {
        switch self {
        case .single(let part):
            let id = prefix.isEmpty ? "1" : prefix
            result.append((id, part))
            if let embedded = part.embedded {
                let embeddedPrefix = "\(id).1"
                embedded.enumerateParts(prefix: embeddedPrefix, into: &result)
            }
        case .multipart(let multipart):
            for (index, child) in multipart.parts.enumerated() {
                let childId = prefix.isEmpty ? String(index + 1) : "\(prefix).\(index + 1)"
                child.enumerateParts(prefix: childId, into: &result)
            }
        }
    }

    private func node(for path: [Int]) -> ImapBodyStructure? {
        guard let head = path.first else { return nil }
        switch self {
        case .single(let part):
            guard head == 1 else { return nil }
            if path.count == 1 {
                return self
            }
            guard let embedded = part.embedded else { return nil }
            let remaining = Array(path.dropFirst())
            return embedded.node(for: remaining)
        case .multipart(let multipart):
            let index = head - 1
            guard index >= 0, index < multipart.parts.count else { return nil }
            let child = multipart.parts[index]
            if path.count == 1 {
                return child
            }
            let remaining = Array(path.dropFirst())
            return child.node(for: remaining)
        }
    }

    private static func parsePartPath(_ id: String) -> [Int]? {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: true)
        guard !parts.isEmpty else { return nil }
        var result: [Int] = []
        for part in parts {
            guard let value = Int(part), value > 0 else { return nil }
            result.append(value)
        }
        return result
    }
}

/// The scope of a body section reference.
///
/// Indicates whether the section refers to the entire message or a specific part.
public enum ImapBodySectionScope: Sendable, Equatable {
    /// The section refers to the entire message.
    case message(node: ImapBodyStructure)

    /// The section refers to a specific part within the message.
    case part(id: String, node: ImapBodyStructure)

    /// The body structure node at this scope.
    public var node: ImapBodyStructure {
        switch self {
        case .message(let node):
            return node
        case .part(_, let node):
            return node
        }
    }

    /// The part ID if this is a part scope, or `nil` for message scope.
    public var partId: String? {
        switch self {
        case .message:
            return nil
        case .part(let id, _):
            return id
        }
    }
}

/// The result of resolving a body section against a body structure.
///
/// This type provides information about which part of the message a section
/// specifier refers to, including the content type and any multipart boundary.
public struct ImapBodySectionResolution: Sendable, Equatable {
    /// The scope of the resolution (message or part).
    public let scope: ImapBodySectionScope

    /// The subsection specifier (HEADER, TEXT, MIME), if any.
    public let subsection: ImapFetchBodySubsection?

    /// The content type of the resolved section.
    ///
    /// For single parts, this is the full type/subtype (e.g., "TEXT/PLAIN").
    /// For multipart containers, this is "MULTIPART/subtype".
    public var contentType: String? {
        switch scope.node {
        case .single(let part):
            return "\(part.type)/\(part.subtype)"
        case .multipart(let multipart):
            return "MULTIPART/\(multipart.subtype)"
        }
    }

    /// The multipart subtype if the resolved section is a multipart.
    public var multipartSubtype: String? {
        if case let .multipart(multipart) = scope.node {
            return multipart.subtype
        }
        return nil
    }

    /// The multipart parameters if the resolved section is a multipart.
    public var multipartParameters: [String: String] {
        if case let .multipart(multipart) = scope.node {
            return multipart.parameters
        }
        return [:]
    }

    /// The MIME boundary parameter for multipart sections.
    public var boundary: String? {
        multipartParameters["BOUNDARY"]
    }
}

private enum ImapBodyNode: Equatable {
    case list([ImapBodyNode])
    case string(String)
    case number(Int)
    case nilValue
}

private struct ImapBodyStructureParser {
    private let bytes: [UInt8]
    private var index: Int = 0

    init(text: String) {
        self.bytes = Array(text.utf8)
    }

    mutating func parse() -> ImapBodyNode? {
        skipWhitespace()
        guard let node = parseNode() else { return nil }
        return node
    }

    private mutating func parseNode() -> ImapBodyNode? {
        skipWhitespace()
        guard index < bytes.count else { return nil }
        let byte = bytes[index]
        if byte == 40 { // '('
            index += 1
            var items: [ImapBodyNode] = []
            while true {
                skipWhitespace()
                if index >= bytes.count {
                    return nil
                }
                if bytes[index] == 41 { // ')'
                    index += 1
                    break
                }
                guard let item = parseNode() else { return nil }
                items.append(item)
            }
            return .list(items)
        }
        if byte == 34 { // '"'
            return parseQuoted()
        }
        if byte == 123 { // '{'
            return parseLiteral()
        }
        return parseAtom()
    }

    private mutating func parseQuoted() -> ImapBodyNode? {
        guard index < bytes.count, bytes[index] == 34 else { return nil }
        index += 1
        var output: [UInt8] = []
        var escape = false
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            if escape {
                output.append(byte)
                escape = false
                continue
            }
            if byte == 92 { // '\\'
                escape = true
                continue
            }
            if byte == 34 { // '"'
                return .string(String(decoding: output, as: UTF8.self))
            }
            output.append(byte)
        }
        return nil
    }

    private mutating func parseLiteral() -> ImapBodyNode? {
        guard index < bytes.count, bytes[index] == 123 else { return nil }
        index += 1
        var countValue: Int = 0
        var hasDigits = false
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 125 { // '}'
                index += 1
                break
            }
            guard byte >= 48, byte <= 57 else { return nil }
            hasDigits = true
            countValue = countValue * 10 + Int(byte - 48)
            index += 1
        }
        guard hasDigits else { return nil }
        if index + 1 < bytes.count, bytes[index] == 13, bytes[index + 1] == 10 {
            index += 2
        }
        guard index + countValue <= bytes.count else { return nil }
        let literalBytes = Array(bytes[index..<index + countValue])
        index += countValue
        return .string(String(decoding: literalBytes, as: UTF8.self))
    }

    private mutating func parseAtom() -> ImapBodyNode? {
        let start = index
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 32 || byte == 9 || byte == 10 || byte == 13 || byte == 40 || byte == 41 {
                break
            }
            index += 1
        }
        guard start < index else { return nil }
        let token = String(decoding: bytes[start..<index], as: UTF8.self)
        if token.uppercased() == "NIL" {
            return .nilValue
        }
        if let number = Int(token) {
            return .number(number)
        }
        return .string(token)
    }

    private mutating func skipWhitespace() {
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 32 || byte == 9 || byte == 10 || byte == 13 {
                index += 1
            } else {
                break
            }
        }
    }
}

private func parseNode(_ node: ImapBodyNode) -> ImapBodyStructure? {
    guard case let .list(items) = node else { return nil }
    guard !items.isEmpty else { return nil }

    if case .list = items[0] {
        return parseMultipart(items)
    }
    return parseSingle(items)
}

private func parseMultipart(_ items: [ImapBodyNode]) -> ImapBodyStructure? {
    var parts: [ImapBodyStructure] = []
    var index = 0
    while index < items.count {
        if case .list = items[index] {
            if let part = parseNode(items[index]) {
                parts.append(part)
                index += 1
                continue
            }
            return nil
        }
        break
    }

    guard index < items.count, let subtype = nodeString(items[index]) else { return nil }
    index += 1

    var parameters: [String: String] = [:]
    if index < items.count, let params = parseParameters(items[index]) {
        parameters = params
        index += 1
    } else if index < items.count, case .nilValue = items[index] {
        index += 1
    }

    let disposition = parseDisposition(from: items, index: &index)
    let language = parseLanguage(from: items, index: &index)
    let location = parseLocation(from: items, index: &index)
    let extensions = parseExtensions(from: items, index: &index)

    let multipart = ImapMultipart(
        parts: parts,
        subtype: subtype,
        parameters: parameters,
        disposition: disposition,
        language: language,
        location: location,
        extensions: extensions
    )
    return .multipart(multipart)
}

private func parseSingle(_ items: [ImapBodyNode]) -> ImapBodyStructure? {
    guard items.count >= 7 else { return nil }
    guard let type = nodeString(items[0]), let subtype = nodeString(items[1]) else { return nil }
    let parameters = parseParameters(items[2]) ?? [:]
    let id = nodeString(items[3])
    let description = nodeString(items[4])
    let encoding = nodeString(items[5])
    let size = nodeInt(items[6])

    var index = 7
    var lines: Int?
    var envelopeRaw: String?
    var embedded: ImapBodyStructure?

    if type.uppercased() == "TEXT", index < items.count {
        lines = nodeInt(items[index])
        index += 1
    } else if type.uppercased() == "MESSAGE", subtype.uppercased() == "RFC822" {
        if index < items.count {
            envelopeRaw = renderNode(items[index])
            index += 1
        }
        if index < items.count {
            embedded = parseNode(items[index])
            index += 1
        }
        if index < items.count {
            lines = nodeInt(items[index])
            index += 1
        }
    }

    let md5 = parseOptionalString(from: items, index: &index)
    let disposition = parseDisposition(from: items, index: &index)
    let language = parseLanguage(from: items, index: &index)
    let location = parseLocation(from: items, index: &index)
    let extensions = parseExtensions(from: items, index: &index)

    let part = ImapBodyPart(
        type: type,
        subtype: subtype,
        parameters: parameters,
        id: id,
        description: description,
        encoding: encoding,
        size: size,
        lines: lines,
        md5: md5,
        envelopeRaw: envelopeRaw,
        embedded: embedded,
        disposition: disposition,
        language: language,
        location: location,
        extensions: extensions
    )
    return .single(part)
}

private func parseParameters(_ node: ImapBodyNode) -> [String: String]? {
    guard case let .list(items) = node else { return nil }
    var result: [String: String] = [:]
    var index = 0
    while index + 1 < items.count {
        guard let key = nodeString(items[index]) else { return nil }
        guard let value = nodeString(items[index + 1]) else { return nil }
        result[key.uppercased()] = value
        index += 2
    }
    return result
}

private func parseDisposition(from items: [ImapBodyNode], index: inout Int) -> ImapContentDisposition? {
    guard index < items.count else { return nil }
    if case .nilValue = items[index] {
        index += 1
        return nil
    }
    guard case let .list(values) = items[index], values.count >= 1 else { return nil }
    guard let type = nodeString(values[0]) else { return nil }
    var parameters: [String: String] = [:]
    if values.count > 1, let params = parseParameters(values[1]) {
        parameters = params
    }
    index += 1
    return ImapContentDisposition(type: type, parameters: parameters)
}

private func parseLanguage(from items: [ImapBodyNode], index: inout Int) -> [String]? {
    guard index < items.count else { return nil }
    let node = items[index]
    if let value = nodeString(node) {
        index += 1
        return [value]
    }
    if case .nilValue = node {
        index += 1
        return nil
    }
    if case let .list(values) = node {
        let langs = values.compactMap(nodeString)
        index += 1
        return langs.isEmpty ? nil : langs
    }
    return nil
}

private func parseLocation(from items: [ImapBodyNode], index: inout Int) -> String? {
    guard index < items.count else { return nil }
    if let value = nodeString(items[index]) {
        index += 1
        return value
    }
    if case .nilValue = items[index] {
        index += 1
        return nil
    }
    return nil
}

private func parseOptionalString(from items: [ImapBodyNode], index: inout Int) -> String? {
    guard index < items.count else { return nil }
    let node = items[index]
    if case .nilValue = node {
        index += 1
        return nil
    }
    if let value = nodeString(node) {
        index += 1
        return value
    }
    return nil
}

private func parseExtensions(from items: [ImapBodyNode], index: inout Int) -> [String] {
    guard index < items.count else { return [] }
    var result: [String] = []
    while index < items.count {
        result.append(renderNode(items[index]))
        index += 1
    }
    return result
}

private func nodeString(_ node: ImapBodyNode) -> String? {
    switch node {
    case .string(let value):
        return value
    case .number(let value):
        return String(value)
    default:
        return nil
    }
}

private func nodeInt(_ node: ImapBodyNode) -> Int? {
    switch node {
    case .number(let value):
        return value
    case .string(let value):
        return Int(value)
    default:
        return nil
    }
}

private func renderNode(_ node: ImapBodyNode) -> String {
    switch node {
    case .nilValue:
        return "NIL"
    case .number(let value):
        return String(value)
    case .string(let value):
        return quote(value)
    case .list(let items):
        let inner = items.map { renderNode($0) }.joined(separator: " ")
        return "(\(inner))"
    }
}

private func quote(_ value: String) -> String {
    var result = "\""
    for ch in value {
        if ch == "\\" || ch == "\"" {
            result.append("\\")
        }
        result.append(ch)
    }
    result.append("\"")
    return result
}
