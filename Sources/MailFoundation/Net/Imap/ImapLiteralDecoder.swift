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
// ImapLiteralDecoder.swift
//
// Incremental IMAP literal decoder.
//

public struct ImapLiteralMessage: Sendable, Equatable {
    public let line: String
    public let response: ImapResponse?
    public let literal: [UInt8]?
}

public struct ImapLiteralDecoder: Sendable {
    private var lineBuffer = LineBuffer()
    private var pendingLine: String?
    private var pendingLiteralBytes: Int = 0
    private var pendingLiteral: [UInt8] = []

    public init() {}

    public mutating func append(_ bytes: [UInt8]) -> [ImapLiteralMessage] {
        var remaining = bytes[...]
        var messages: [ImapLiteralMessage] = []

        while !remaining.isEmpty {
            if pendingLiteralBytes > 0 {
                let take = min(pendingLiteralBytes, remaining.count)
                pendingLiteral.append(contentsOf: remaining.prefix(take))
                pendingLiteralBytes -= take
                remaining = remaining.dropFirst(take)

                if pendingLiteralBytes == 0, let line = pendingLine {
                    messages.append(ImapLiteralMessage(line: line, response: ImapResponse.parse(line), literal: pendingLiteral))
                    pendingLine = nil
                    pendingLiteral.removeAll(keepingCapacity: true)
                }
                continue
            }

            let lines = lineBuffer.append(remaining)
            remaining = []
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if let literalLength = parseLiteralLength(from: trimmedLine) {
                    if literalLength == 0 {
                        messages.append(ImapLiteralMessage(line: trimmedLine, response: ImapResponse.parse(trimmedLine), literal: []))
                    } else {
                        pendingLine = trimmedLine
                        pendingLiteralBytes = literalLength
                        pendingLiteral.removeAll(keepingCapacity: true)
                    }
                } else {
                    messages.append(ImapLiteralMessage(line: trimmedLine, response: ImapResponse.parse(trimmedLine), literal: nil))
                }
            }
        }

        return messages
    }

    private func parseLiteralLength(from line: String) -> Int? {
        let bytes = Array(line.utf8)
        guard let last = bytes.last, last == 0x7D else { // '}'
            return nil
        }

        var index = bytes.count - 2
        var multiplier = 1
        var value = 0
        var sawDigit = false

        while index >= 0 {
            let byte = bytes[index]
            if byte == 0x7B { // '{'
                return sawDigit ? value : nil
            }
            if byte == 0x2B { // '+'
                index -= 1
                continue
            }
            if byte >= 0x30, byte <= 0x39 {
                sawDigit = true
                value += Int(byte - 0x30) * multiplier
                multiplier *= 10
                index -= 1
                continue
            }
            return nil
        }

        return nil
    }
}
