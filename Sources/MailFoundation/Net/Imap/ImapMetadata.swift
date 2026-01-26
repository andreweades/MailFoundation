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

    public static func parse(_ message: ImapLiteralMessage) -> ImapMetadataResponse? {
        let trimmed = message.line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("*") else { return nil }
        var index = trimmed.index(after: trimmed.startIndex)

        func skipWhitespace() {
            while index < trimmed.endIndex, trimmed[index].isWhitespace {
                index = trimmed.index(after: index)
            }
        }

        func readAtom() -> String? {
            skipWhitespace()
            guard index < trimmed.endIndex else { return nil }
            let start = index
            while index < trimmed.endIndex {
                let ch = trimmed[index]
                if ch.isWhitespace || ch == "(" || ch == ")" {
                    break
                }
                index = trimmed.index(after: index)
            }
            guard start < index else { return nil }
            return String(trimmed[start..<index])
        }

        func readQuoted() -> String? {
            guard index < trimmed.endIndex, trimmed[index] == "\"" else { return nil }
            index = trimmed.index(after: index)
            var result = ""
            var escape = false
            while index < trimmed.endIndex {
                let ch = trimmed[index]
                if escape {
                    result.append(ch)
                    escape = false
                } else if ch == "\\" {
                    escape = true
                } else if ch == "\"" {
                    index = trimmed.index(after: index)
                    return result
                } else {
                    result.append(ch)
                }
                index = trimmed.index(after: index)
            }
            return nil
        }

        func readStringOrNil() -> String?? {
            skipWhitespace()
            guard index < trimmed.endIndex else { return nil }
            if trimmed[index] == "\"" {
                if let value = readQuoted() {
                    return .some(value)
                }
                return nil
            }
            guard let atom = readAtom() else { return nil }
            if atom.uppercased() == "NIL" {
                return .some(nil)
            }
            return .some(atom)
        }

        guard let command = readAtom(), command.uppercased() == "METADATA" else { return nil }
        guard let mailboxValue = readStringOrNil(), let mailbox = mailboxValue else { return nil }

        guard let listStart = trimmed.firstIndex(of: "(") else {
            return ImapMetadataResponse(mailbox: mailbox, entries: [])
        }
        var inner = String(trimmed[listStart...])
        if inner.first == "(" {
            inner.removeFirst()
        }
        if inner.last == ")" {
            inner.removeLast()
        }
        var tokens = tokenize(inner)
        if let literal = message.literal,
           let last = tokens.last,
           isLiteralToken(last) {
            tokens[tokens.count - 1] = String(decoding: literal, as: UTF8.self)
        }

        var entries: [ImapMetadataEntry] = []
        var idx = 0
        while idx + 1 < tokens.count {
            let key = tokens[idx]
            let rawValue = tokens[idx + 1]
            let value = rawValue.caseInsensitiveCompare("NIL") == .orderedSame ? nil : rawValue
            entries.append(ImapMetadataEntry(key: key, value: value))
            idx += 2
        }
        return ImapMetadataResponse(mailbox: mailbox, entries: entries)
    }

    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            let ch = text[index]
            if ch.isWhitespace {
                index = text.index(after: index)
                continue
            }
            if ch == "\"" {
                index = text.index(after: index)
                var value = ""
                var escape = false
                while index < text.endIndex {
                    let current = text[index]
                    if escape {
                        value.append(current)
                        escape = false
                    } else if current == "\\" {
                        escape = true
                    } else if current == "\"" {
                        index = text.index(after: index)
                        break
                    } else {
                        value.append(current)
                    }
                    index = text.index(after: index)
                }
                tokens.append(value)
                continue
            }

            let start = index
            while index < text.endIndex {
                let current = text[index]
                if current.isWhitespace {
                    break
                }
                index = text.index(after: index)
            }
            tokens.append(String(text[start..<index]))
        }
        return tokens
    }

    private static func isLiteralToken(_ token: String) -> Bool {
        token.first == "{"
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
