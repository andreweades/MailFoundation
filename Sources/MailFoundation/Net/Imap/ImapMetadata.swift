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
// ImapMetadata.swift
//
// IMAP METADATA/ANNOTATEMORE helpers.
//

import Foundation

public enum ImapMetadataDepth: Sendable, Equatable {
    case zero
    case one
    case infinity

    var token: String {
        switch self {
        case .zero:
            return "0"
        case .one:
            return "1"
        case .infinity:
            return "infinity"
        }
    }
}

public struct ImapMetadataOptions: Sendable, Equatable {
    public var depth: ImapMetadataDepth?
    public var maxSize: Int?

    public init(depth: ImapMetadataDepth? = nil, maxSize: Int? = nil) {
        self.depth = depth
        self.maxSize = maxSize
    }

    func arguments() -> String? {
        var parts: [String] = []
        if let depth {
            parts.append("DEPTH \(depth.token)")
        }
        if let maxSize {
            parts.append("MAXSIZE \(maxSize)")
        }
        guard !parts.isEmpty else { return nil }
        return "(\(parts.joined(separator: " ")))"
    }
}

public struct ImapMetadataEntry: Sendable, Equatable {
    public let key: String
    public let value: String?

    public init(key: String, value: String?) {
        self.key = key
        self.value = value
    }
}

public struct ImapMetadataResponse: Sendable, Equatable {
    public let mailbox: String
    public let entries: [ImapMetadataEntry]

    /// Parses a METADATA response from a literal-aware message.
    ///
    /// - Parameter message: The literal response message.
    /// - Returns: The parsed metadata response, or `nil` if parsing fails.
    public static func parse(_ message: ImapLiteralMessage) -> ImapMetadataResponse? {
        var reader = ImapLineTokenReader(line: message.line, literals: message.literals)
        guard let token = reader.readToken(), token.type == .asterisk else { return nil }
        guard reader.readCaseInsensitiveAtom("METADATA") else { return nil }
        guard let mailboxToken = reader.readToken() else { return nil }
        guard let mailbox = readStringValue(token: mailboxToken, reader: &reader, allowNil: false) else { return nil }

        var entries: [ImapMetadataEntry] = []
        if let peek = reader.peekToken(), peek.type == .openParen {
            _ = reader.readToken()
            while let next = reader.peekToken() {
                if next.type == .closeParen {
                    _ = reader.readToken()
                    break
                }
                guard let keyToken = reader.readToken(),
                      let key = readStringValue(token: keyToken, reader: &reader, allowNil: false) else {
                    return nil
                }
                guard let valueToken = reader.readToken() else { return nil }
                let value = readStringValue(token: valueToken, reader: &reader, allowNil: true)
                entries.append(ImapMetadataEntry(key: key, value: value))
            }
        }

        return ImapMetadataResponse(mailbox: mailbox, entries: entries)
    }

    private static func readStringValue(
        token: ImapToken,
        reader: inout ImapLineTokenReader,
        allowNil: Bool
    ) -> String? {
        switch token.type {
        case .atom, .qString, .flag:
            return token.stringValue
        case .literal:
            return reader.literalString(for: token)
        case .nilValue:
            return allowNil ? nil : nil
        default:
            return nil
        }
    }
}

enum ImapMetadata {
    static func quote(_ value: String) -> String {
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

    static func atomOrQuoted(_ value: String) -> String {
        for ch in value {
            if ch.isWhitespace || ch == "(" || ch == ")" || ch == "\"" || ch == "\\" {
                return quote(value)
            }
        }
        return value
    }

    static func formatEntryList(_ entries: [String]) -> String {
        let rendered = entries.map { atomOrQuoted($0) }.joined(separator: " ")
        return "(\(rendered))"
    }

    static func formatEntryPairs(_ entries: [ImapMetadataEntry]) -> String {
        let rendered = entries.map { entry in
            let key = atomOrQuoted(entry.key)
            if let value = entry.value {
                return "\(key) \(quote(value))"
            }
            return "\(key) NIL"
        }
        .joined(separator: " ")
        return "(\(rendered))"
    }
}
