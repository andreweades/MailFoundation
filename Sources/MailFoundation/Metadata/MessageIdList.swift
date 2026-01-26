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
// MessageIdList.swift
//
// Helpers for parsing Message-Id style headers (e.g. References, In-Reply-To).
//

import Foundation

public struct MessageIdList: Sendable, Equatable, CustomStringConvertible {
    public let ids: [String]

    public init(_ ids: [String]) {
        self.ids = ids.map(Self.normalizeId).filter { !$0.isEmpty }
    }

    public var description: String {
        ids.map { "<\($0)>" }.joined(separator: " ")
    }

    public static func parse(_ value: String) -> MessageIdList? {
        let ids = parseAll(value)
        guard !ids.isEmpty else { return nil }
        return MessageIdList(ids)
    }

    public static func parseAll(_ value: String) -> [String] {
        var parser = MessageIdParser(value)
        let parsed = parser.parseReferences()
        if !parsed.isEmpty {
            return parsed
        }

        if value.contains("<") || value.contains(">") {
            return []
        }

        return parseBareTokens(value)
    }

    public static func parseMessageId(_ value: String) -> String? {
        var parser = MessageIdParser(value)
        return parser.parseMessageId(requireAngleAddr: false)
    }

    private static func normalizeId(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return trimmed }
        if trimmed.first == "<", trimmed.last == ">" {
            let start = trimmed.index(after: trimmed.startIndex)
            let end = trimmed.index(before: trimmed.endIndex)
            return String(trimmed[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private static func parseBareTokens(_ value: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var commentDepth = 0
        var escaped = false

        for ch in value {
            if escaped {
                if commentDepth == 0 {
                    current.append(ch)
                }
                escaped = false
                continue
            }

            if ch == "\\" {
                escaped = true
                continue
            }

            if ch == "(" {
                commentDepth += 1
                continue
            }
            if ch == ")" {
                if commentDepth > 0 {
                    commentDepth -= 1
                    continue
                }
            }
            if commentDepth > 0 {
                continue
            }

            if ch == "," || ch.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }

            current.append(ch)
        }

        if commentDepth > 0 {
            return []
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
            .map { normalizeId($0) }
            .filter { !$0.isEmpty }
    }
}

private struct MessageIdParser {
    private let bytes: [UInt8]
    private let endIndex: Int
    private var index: Int = 0

    init(_ value: String) {
        self.bytes = Array(value.utf8)
        self.endIndex = bytes.count
    }

    mutating func parseReferences() -> [String] {
        var results: [String] = []

        while index < endIndex {
            guard skipCommentsAndWhiteSpace() else {
                return []
            }

            if index >= endIndex { break }

            if bytes[index] == MessageIdParser.lessThan {
                let start = index
                if let msgid = parseMessageId(requireAngleAddr: true) {
                    results.append(msgid)
                } else if index == start {
                    index += 1
                }
            } else if !skipWord() {
                index += 1
            }
        }

        return results
    }

    mutating func parseMessageId(requireAngleAddr: Bool) -> String? {
        let tokenStartIndex = index
        guard skipCommentsAndWhiteSpace() else { return nil }

        if index >= endIndex { return nil }
        if requireAngleAddr && bytes[index] != MessageIdParser.lessThan { return nil }

        var angleAddr = false
        if bytes[index] == MessageIdParser.lessThan {
            angleAddr = true
            index += 1
        }

        skipWhiteSpace()
        if index >= endIndex { return nil }

        var token = ""
        var squareBrackets = false

        if bytes[index] == MessageIdParser.openBracket {
            squareBrackets = true
        }

        while true {
            let segmentStart = index
            if bytes[index] == MessageIdParser.quote {
                guard skipQuoted() else { return nil }
            } else {
                while index < endIndex {
                    let byte = bytes[index]
                    if byte == MessageIdParser.dot ||
                        byte == MessageIdParser.atSign ||
                        byte == MessageIdParser.greaterThan ||
                        isWhiteSpace(byte) {
                        break
                    }
                    index += 1
                }
            }

            if segmentStart == index { return nil }
            token.append(String(decoding: bytes[segmentStart..<index], as: UTF8.self))

            skipWhiteSpace()

            if index >= endIndex {
                if angleAddr { return nil }
                break
            }

            let byte = bytes[index]
            if byte == MessageIdParser.atSign || byte == MessageIdParser.greaterThan {
                break
            }

            if byte == MessageIdParser.dot {
                token.append(".")
                index += 1
                skipWhiteSpace()
                if index >= endIndex {
                    return nil
                }
                continue
            }

            if index == segmentStart {
                return nil
            }
        }

        if index < endIndex && bytes[index] == MessageIdParser.atSign {
            token.append("@")
            index += 1

            while index < endIndex && bytes[index] == MessageIdParser.atSign {
                index += 1
            }

            guard skipCommentsAndWhiteSpace() else { return nil }

            if index < endIndex && bytes[index] != MessageIdParser.greaterThan {
                while true {
                    guard let domain = parseDomain() else { return nil }
                    token.append(domain)

                    if index >= endIndex || bytes[index] != MessageIdParser.atSign {
                        break
                    }

                    token.append("@")
                    index += 1
                }

                guard skipCommentsAndWhiteSpace() else { return nil }
            }
        }

        if squareBrackets, index < endIndex, bytes[index] == MessageIdParser.closeBracket {
            token.append("]")
            index += 1
        }

        if angleAddr, (index >= endIndex || bytes[index] != MessageIdParser.greaterThan) {
            return nil
        }

        if index < endIndex && bytes[index] == MessageIdParser.greaterThan {
            index += 1
        }

        if token.isEmpty {
            index = tokenStartIndex
            return nil
        }

        return token
    }

    private mutating func parseDomain() -> String? {
        if bytes[index] == MessageIdParser.openBracket {
            return parseDomainLiteral()
        }

        let start = index
        while index < endIndex {
            let byte = bytes[index]
            if byte == MessageIdParser.dot {
                index += 1
                continue
            }
            if isAtext(byte) {
                index += 1
                continue
            }
            break
        }

        guard index > start else { return nil }
        return String(decoding: bytes[start..<index], as: UTF8.self)
    }

    private mutating func parseDomainLiteral() -> String? {
        let start = index
        index += 1

        while index < endIndex {
            let byte = bytes[index]
            if byte == MessageIdParser.closeBracket {
                index += 1
                return String(decoding: bytes[start..<index], as: UTF8.self)
            }
            if isWhiteSpace(byte) {
                index += 1
                continue
            }
            if byte < 33 {
                return nil
            }
            index += 1
        }

        return nil
    }

    private mutating func skipCommentsAndWhiteSpace() -> Bool {
        while true {
            skipWhiteSpace()
            if index >= endIndex { return true }
            if bytes[index] == MessageIdParser.openParen {
                guard skipComment() else { return false }
                continue
            }
            return true
        }
    }

    private mutating func skipWhiteSpace() {
        while index < endIndex, isWhiteSpace(bytes[index]) {
            index += 1
        }
    }

    private mutating func skipComment() -> Bool {
        var depth = 0
        if bytes[index] == MessageIdParser.openParen {
            depth = 1
            index += 1
        }

        while index < endIndex {
            let byte = bytes[index]
            if byte == MessageIdParser.escape {
                index += 2
                continue
            }
            if byte == MessageIdParser.openParen {
                depth += 1
                index += 1
                continue
            }
            if byte == MessageIdParser.closeParen {
                depth -= 1
                index += 1
                if depth == 0 { return true }
                continue
            }
            index += 1
        }
        return false
    }

    private mutating func skipQuoted() -> Bool {
        guard bytes[index] == MessageIdParser.quote else { return false }
        index += 1
        while index < endIndex {
            let byte = bytes[index]
            if byte == MessageIdParser.escape {
                index += 2
                continue
            }
            if byte == MessageIdParser.quote {
                index += 1
                return true
            }
            index += 1
        }
        return false
    }

    private mutating func skipWord() -> Bool {
        let start = index
        while index < endIndex {
            let byte = bytes[index]
            if isWhiteSpace(byte) || byte == MessageIdParser.openParen || byte == MessageIdParser.lessThan {
                break
            }
            index += 1
        }
        return index > start
    }

    private func isWhiteSpace(_ byte: UInt8) -> Bool {
        byte == MessageIdParser.space || byte == MessageIdParser.tab || byte == MessageIdParser.cr || byte == MessageIdParser.lf
    }

    private func isAtext(_ byte: UInt8) -> Bool {
        if byte >= MessageIdParser.upperA && byte <= MessageIdParser.upperZ { return true }
        if byte >= MessageIdParser.lowerA && byte <= MessageIdParser.lowerZ { return true }
        if byte >= MessageIdParser.zero && byte <= MessageIdParser.nine { return true }
        return MessageIdParser.atextSet.contains(byte)
    }

    private static let atextSet: Set<UInt8> = Set("!#$%&'*+-/=?^_`{|}~".utf8)
    private static let space: UInt8 = 0x20
    private static let tab: UInt8 = 0x09
    private static let cr: UInt8 = 0x0D
    private static let lf: UInt8 = 0x0A
    private static let lessThan: UInt8 = 0x3C
    private static let greaterThan: UInt8 = 0x3E
    private static let atSign: UInt8 = 0x40
    private static let dot: UInt8 = 0x2E
    private static let quote: UInt8 = 0x22
    private static let escape: UInt8 = 0x5C
    private static let openParen: UInt8 = 0x28
    private static let closeParen: UInt8 = 0x29
    private static let openBracket: UInt8 = 0x5B
    private static let closeBracket: UInt8 = 0x5D
    private static let upperA: UInt8 = 0x41
    private static let upperZ: UInt8 = 0x5A
    private static let lowerA: UInt8 = 0x61
    private static let lowerZ: UInt8 = 0x7A
    private static let zero: UInt8 = 0x30
    private static let nine: UInt8 = 0x39
}
