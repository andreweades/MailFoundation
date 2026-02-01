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
// ImapLineTokenReader.swift
//
// Token reader for parsed IMAP response lines with optional literals.
//

import Foundation

struct ImapLineTokenReader {
    private static let atomSpecials = ImapTokenStream.atomSpecials
    private static let defaultSpecials = ImapTokenStream.defaultSpecials

    private let bytes: [UInt8]
    private var index: Int = 0
    private var peeked: ImapToken?
    private let literals: [[UInt8]]
    private var literalCursor: Int = 0

    init(line: String, literals: [[UInt8]] = []) {
        self.bytes = Array(line.utf8)
        self.literals = literals
    }

    var currentIndex: Int {
        index
    }

    mutating func readToken(specials: String = ImapLineTokenReader.defaultSpecials) -> ImapToken? {
        if let peeked {
            self.peeked = nil
            return peeked
        }

        skipWhitespace()
        guard index < bytes.count else { return nil }

        let byte = bytes[index]
        if byte == 0x22 { // '"'
            guard let value = readQuotedString() else { return nil }
            return ImapToken(type: .qString, stringValue: value)
        }

        if byte == 0x7B { // '{'
            guard let literalLength = readLiteralLength() else { return nil }
            let literalIndex = literalCursor
            literalCursor += 1
            return ImapToken(type: .literal, numberValue: literalLength, literalIndex: literalIndex)
        }

        if byte == 0x5C { // '\\'
            index += 1
            guard let value = readAtom(specials: specials) else { return nil }
            return ImapToken(type: .flag, stringValue: "\\" + value)
        }

        if isAtomChar(byte, specials: specials) {
            guard let value = readAtom(specials: specials) else { return nil }
            if value.uppercased() == "NIL" {
                return ImapToken(type: .nilValue, stringValue: value)
            }
            return ImapToken(type: .atom, stringValue: value)
        }

        index += 1
        switch byte {
        case 0x28: return ImapToken(type: .openParen)
        case 0x29: return ImapToken(type: .closeParen)
        case 0x2A: return ImapToken(type: .asterisk)
        case 0x5B: return ImapToken(type: .openBracket)
        case 0x5D: return ImapToken(type: .closeBracket)
        default: return ImapToken(type: .error)
        }
    }

    mutating func peekToken(specials: String = ImapLineTokenReader.defaultSpecials) -> ImapToken? {
        if let peeked { return peeked }
        let token = readToken(specials: specials)
        peeked = token
        return token
    }

    mutating func readAtomString() -> String? {
        guard let token = readToken() else { return nil }
        guard token.type == .atom else { return nil }
        return token.stringValue
    }

    mutating func readCaseInsensitiveAtom(_ value: String) -> Bool {
        guard let token = readToken() else { return false }
        guard token.type == .atom, let atom = token.stringValue else { return false }
        return atom.caseInsensitiveCompare(value) == .orderedSame
    }

    mutating func readNumber() -> Int? {
        guard let token = readToken() else { return nil }
        switch token.type {
        case .atom, .qString, .flag:
            guard let value = token.stringValue else { return nil }
            return Int(value)
        case .literal:
            guard let string = literalString(for: token) else { return nil }
            return Int(string)
        case .nilValue:
            return nil
        default:
            return nil
        }
    }

    mutating func readNString() -> String? {
        guard let token = readToken() else { return nil }
        switch token.type {
        case .atom, .qString, .flag:
            return token.stringValue
        case .literal:
            return literalString(for: token)
        case .nilValue:
            return nil
        default:
            return nil
        }
    }

    mutating func readValueString(materializeLiterals: Bool) -> String? {
        guard let token = readToken() else { return nil }
        return serializeToken(token, materializeLiterals: materializeLiterals)
    }

    mutating func readBracketedContent(materializeLiterals: Bool) -> String? {
        guard let token = readToken(), token.type == .openBracket else { return nil }
        let inner = readDelimitedString(close: .closeBracket, materializeLiterals: materializeLiterals)
        return inner
    }

    mutating func skipValue() {
        guard let token = readToken() else { return }
        _ = skipToken(token)
    }

    func remainingString(trimLeadingWhitespace: Bool = true) -> String {
        var start = index
        if trimLeadingWhitespace {
            while start < bytes.count {
                let byte = bytes[start]
                if byte == 0x20 || byte == 0x0D {
                    start += 1
                } else {
                    break
                }
            }
        }
        guard start < bytes.count else { return "" }
        return String(decoding: bytes[start...], as: UTF8.self)
    }

    func literalBytes(for token: ImapToken) -> [UInt8]? {
        guard token.type == .literal, let literalIndex = token.literalIndex else { return nil }
        guard literalIndex >= 0, literalIndex < literals.count else { return nil }
        return literals[literalIndex]
    }

    func literalString(for token: ImapToken) -> String? {
        guard let bytes = literalBytes(for: token) else { return nil }
        if let utf8 = String(bytes: bytes, encoding: .utf8) {
            return utf8
        }
        if let latin1 = String(bytes: bytes, encoding: .isoLatin1) {
            return latin1
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    func quotedLiteralString(for token: ImapToken) -> String? {
        guard let value = literalString(for: token) else { return nil }
        return quoteImapString(value)
    }

    private mutating func skipToken(_ token: ImapToken) -> Bool {
        switch token.type {
        case .openParen:
            _ = readDelimitedString(close: .closeParen, materializeLiterals: false)
            return true
        case .openBracket:
            _ = readDelimitedString(close: .closeBracket, materializeLiterals: false)
            return true
        default:
            return true
        }
    }

    private mutating func readDelimitedString(close: ImapTokenType, materializeLiterals: Bool) -> String? {
        var parts: [String] = []
        while let token = readToken() {
            if token.type == close {
                break
            }
            if token.type == .openParen {
                guard let nested = readDelimitedString(close: .closeParen, materializeLiterals: materializeLiterals) else { return nil }
                parts.append("(\(nested))")
                continue
            }
            if token.type == .openBracket {
                guard let nested = readDelimitedString(close: .closeBracket, materializeLiterals: materializeLiterals) else { return nil }
                parts.append("[\(nested)]")
                continue
            }
            if let serialized = serializeToken(token, materializeLiterals: materializeLiterals, wrapLists: false) {
                parts.append(serialized)
            }
        }
        return parts.joined(separator: " ")
    }

    private mutating func serializeToken(
        _ token: ImapToken,
        materializeLiterals: Bool,
        wrapLists: Bool = true
    ) -> String? {
        switch token.type {
        case .atom, .flag:
            return token.stringValue
        case .qString:
            guard let value = token.stringValue else { return nil }
            return quoteImapString(value)
        case .literal:
            if materializeLiterals {
                return quotedLiteralString(for: token)
            }
            if let length = token.numberValue {
                return "{\(length)}"
            }
            return "{}"
        case .nilValue:
            return "NIL"
        case .openParen:
            guard let nested = readDelimitedString(close: .closeParen, materializeLiterals: materializeLiterals) else { return nil }
            return wrapLists ? "(\(nested))" : nested
        case .openBracket:
            guard let nested = readDelimitedString(close: .closeBracket, materializeLiterals: materializeLiterals) else { return nil }
            return wrapLists ? "[\(nested)]" : nested
        default:
            return nil
        }
    }

    private mutating func skipWhitespace() {
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 0x20 || byte == 0x0D || byte == 0x0A {
                index += 1
            } else {
                break
            }
        }
    }

    private func isAtomChar(_ byte: UInt8, specials: String) -> Bool {
        if byte <= 0x1F || byte == 0x7F || byte == 0x20 {
            return false
        }
        return !specials.utf8.contains(byte)
    }

    private mutating func readAtom(specials: String) -> String? {
        let start = index
        while index < bytes.count, isAtomChar(bytes[index], specials: specials) {
            index += 1
        }
        guard start < index else { return nil }
        return String(decoding: bytes[start..<index], as: UTF8.self)
    }

    private mutating func readQuotedString() -> String? {
        index += 1 // skip opening quote
        var escaped = false
        var result: [UInt8] = []
        result.reserveCapacity(32)
        while index < bytes.count {
            let byte = bytes[index]
            if escaped {
                result.append(byte)
                escaped = false
                index += 1
                continue
            }
            if byte == 0x5C { // '\\'
                escaped = true
                index += 1
                continue
            }
            if byte == 0x22 { // '"'
                index += 1
                return String(decoding: result, as: UTF8.self)
            }
            result.append(byte)
            index += 1
        }
        return nil
    }

    private mutating func readLiteralLength() -> Int? {
        guard bytes[index] == 0x7B else { return nil } // '{'
        index += 1
        var lengthValue = 0
        var sawDigit = false
        while index < bytes.count {
            let byte = bytes[index]
            if byte >= 0x30 && byte <= 0x39 {
                sawDigit = true
                lengthValue = lengthValue * 10 + Int(byte - 0x30)
                index += 1
                continue
            }
            break
        }
        guard sawDigit else { return nil }
        if index < bytes.count, bytes[index] == 0x2B { // '+'
            index += 1
        }
        guard index < bytes.count, bytes[index] == 0x7D else { return nil } // '}'
        index += 1
        return lengthValue
    }

    private func quoteImapString(_ value: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(value.count + 2)
        for ch in value {
            if ch == "\\" || ch == "\"" {
                escaped.append("\\")
            }
            escaped.append(ch)
        }
        return "\"\(escaped)\""
    }
}
