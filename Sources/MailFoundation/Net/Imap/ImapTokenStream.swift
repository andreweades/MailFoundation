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
// ImapTokenStream.swift
//
// Incremental IMAP token stream for parsing responses with literals.
//

import Foundation

struct ImapTokenStream: Sendable {
    static let atomSpecials = "(){%*\\\""
    static let defaultSpecials = "[]" + atomSpecials

    private var buffer: [UInt8] = []
    private var index: Int = 0

    mutating func append(_ bytes: [UInt8]) {
        buffer.append(contentsOf: bytes)
    }

    var hasBufferedData: Bool {
        index < buffer.count
    }

    mutating func readToken(specials: String = ImapTokenStream.defaultSpecials) -> ImapTokenScan? {
        guard index < buffer.count else { return nil }
        let start = index
        var i = index

        while i < buffer.count, isWhiteSpace(buffer[i]) {
            i += 1
        }

        guard i < buffer.count else {
            return nil
        }

        let byte = buffer[i]
        if byte == 0x0A { // '\n'
            i += 1
            let consumed = Array(buffer[start..<i])
            index = i
            compactIfNeeded()
            return ImapTokenScan(token: .eoln, consumed: consumed)
        }

        if byte == 0x22 { // '"'
            guard let (value, endIndex) = parseQuotedString(from: i) else { return nil }
            let consumed = Array(buffer[start..<endIndex])
            index = endIndex
            compactIfNeeded()
            return ImapTokenScan(token: ImapToken(type: .qString, stringValue: value), consumed: consumed)
        }

        if byte == 0x7B { // '{'
            guard let literal = parseLiteral(from: i) else { return nil }
            let consumed = Array(buffer[start..<literal.markerEnd])
            index = literal.afterNewline
            compactIfNeeded()
            return ImapTokenScan(
                token: ImapToken(type: .literal, numberValue: literal.length),
                consumed: consumed
            )
        }

        if byte == 0x5C { // '\\'
            guard let (value, endIndex) = parseAtom(from: i + 1, specials: specials) else { return nil }
            let consumed = Array(buffer[start..<endIndex])
            index = endIndex
            compactIfNeeded()
            return ImapTokenScan(
                token: ImapToken(type: .flag, stringValue: "\\" + value),
                consumed: consumed
            )
        }

        if isAtomChar(byte, specials: specials) {
            guard let (value, endIndex) = parseAtom(from: i, specials: specials) else { return nil }
            let consumed = Array(buffer[start..<endIndex])
            index = endIndex
            compactIfNeeded()
            if value.uppercased() == "NIL" {
                return ImapTokenScan(token: ImapToken(type: .nilValue, stringValue: value), consumed: consumed)
            }
            return ImapTokenScan(token: ImapToken(type: .atom, stringValue: value), consumed: consumed)
        }

        let tokenType: ImapTokenType
        switch byte {
        case 0x28: // '('
            tokenType = .openParen
        case 0x29: // ')'
            tokenType = .closeParen
        case 0x2A: // '*'
            tokenType = .asterisk
        case 0x5B: // '['
            tokenType = .openBracket
        case 0x5D: // ']'
            tokenType = .closeBracket
        default:
            tokenType = .error
        }

        i += 1
        let consumed = Array(buffer[start..<i])
        index = i
        compactIfNeeded()
        return ImapTokenScan(token: ImapToken(type: tokenType), consumed: consumed)
    }

    mutating func readLiteralChunk(max count: Int) -> [UInt8] {
        guard count > 0 else { return [] }
        let available = buffer.count - index
        guard available > 0 else { return [] }
        let take = min(count, available)
        let chunk = Array(buffer[index..<(index + take)])
        index += take
        compactIfNeeded()
        return chunk
    }

    private mutating func compactIfNeeded() {
        if index > 8192 {
            buffer.removeFirst(index)
            index = 0
        } else if index == buffer.count {
            buffer.removeAll(keepingCapacity: true)
            index = 0
        }
    }

    private func isWhiteSpace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x0D
    }

    private func isAtomChar(_ byte: UInt8, specials: String) -> Bool {
        if byte <= 0x1F || byte == 0x7F || byte == 0x20 {
            return false
        }
        return !specials.utf8.contains(byte)
    }

    private func parseAtom(from start: Int, specials: String) -> (String, Int)? {
        var i = start
        while i < buffer.count, isAtomChar(buffer[i], specials: specials) {
            i += 1
        }
        guard i < buffer.count else {
            return nil
        }
        let value = String(decoding: buffer[start..<i], as: UTF8.self)
        return (value, i)
    }

    private func parseQuotedString(from start: Int) -> (String, Int)? {
        var i = start + 1
        var escaped = false
        var bytes: [UInt8] = []
        bytes.reserveCapacity(32)
        while i < buffer.count {
            let byte = buffer[i]
            if escaped {
                bytes.append(byte)
                escaped = false
                i += 1
                continue
            }
            if byte == 0x5C { // '\\'
                escaped = true
                i += 1
                continue
            }
            if byte == 0x22 { // '"'
                i += 1
                let value = String(decoding: bytes, as: UTF8.self)
                return (value, i)
            }
            bytes.append(byte)
            i += 1
        }
        return nil
    }

    private func parseLiteral(from start: Int) -> (length: Int, markerEnd: Int, afterNewline: Int)? {
        var i = start + 1
        var lengthValue = 0
        var sawDigit = false

        while i < buffer.count {
            let byte = buffer[i]
            if byte >= 0x30 && byte <= 0x39 {
                sawDigit = true
                lengthValue = lengthValue * 10 + Int(byte - 0x30)
                i += 1
                continue
            }
            break
        }

        if i >= buffer.count {
            return nil
        }

        if !sawDigit {
            return nil
        }

        if buffer[i] == 0x2B { // '+'
            i += 1
            if i >= buffer.count {
                return nil
            }
        }

        guard buffer[i] == 0x7D else { // '}'
            return nil
        }

        let markerEnd = i + 1
        i += 1

        if i >= buffer.count {
            return nil
        }

        if buffer[i] == 0x0D {
            if i + 1 >= buffer.count {
                return nil
            }
            if buffer[i + 1] == 0x0A {
                i += 2
            } else {
                i += 1
            }
        } else if buffer[i] == 0x0A {
            i += 1
        } else {
            return nil
        }

        return (lengthValue, markerEnd, i)
    }
}
