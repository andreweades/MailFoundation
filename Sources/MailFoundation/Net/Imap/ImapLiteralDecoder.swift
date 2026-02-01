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
    /// The response line with any literal markers preserved.
    public let line: String
    /// The parsed response, if available.
    public let response: ImapResponse?
    /// Convenience accessor for a single literal payload (if exactly one literal was present).
    public let literal: [UInt8]?
    /// All literal payloads, in the order they appeared in the response line.
    public let literals: [[UInt8]]

    public init(line: String, response: ImapResponse?, literal: [UInt8]?, literals: [[UInt8]] = []) {
        self.line = line
        self.response = response
        self.literal = literal
        if literals.isEmpty, let literal {
            self.literals = [literal]
        } else {
            self.literals = literals
        }
    }
}

import Foundation

public struct ImapLiteralDecoder: Sendable {
    private var tokenStream = ImapTokenStream()
    private var pendingLineBytes: [UInt8] = []
    private var pendingLiteralBytes: Int = 0
    private var pendingLiteralBuffer: [UInt8] = []
    private var pendingLiterals: [[UInt8]] = []

    public init() {}

    /// Returns true if the decoder is currently accumulating a literal or has partial data.
    /// This can be used to distinguish between "no data available" and "still waiting for more data".
    public var hasPendingData: Bool {
        tokenStream.hasBufferedData || pendingLiteralBytes > 0 || !pendingLineBytes.isEmpty
    }

    public mutating func append(_ bytes: [UInt8]) -> [ImapLiteralMessage] {
        tokenStream.append(bytes)
        var messages: [ImapLiteralMessage] = []

        while true {
            if pendingLiteralBytes > 0 {
                let chunk = tokenStream.readLiteralChunk(max: pendingLiteralBytes)
                if chunk.isEmpty {
                    break
                }
                pendingLiteralBuffer.append(contentsOf: chunk)
                pendingLiteralBytes -= chunk.count
                if pendingLiteralBytes == 0 {
                    pendingLiterals.append(pendingLiteralBuffer)
                    pendingLiteralBuffer.removeAll(keepingCapacity: true)
                }
                continue
            }

            guard let scan = tokenStream.readToken() else {
                break
            }

            if scan.token.type == .eoln {
                let line = String(decoding: pendingLineBytes, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !line.isEmpty {
                    let literals = pendingLiterals
                    let literal = literals.count == 1 ? literals[0] : nil
                    messages.append(ImapLiteralMessage(
                        line: line,
                        response: ImapResponse.parse(line),
                        literal: literal,
                        literals: literals
                    ))
                }
                pendingLineBytes.removeAll(keepingCapacity: true)
                pendingLiterals.removeAll(keepingCapacity: true)
                continue
            }

            pendingLineBytes.append(contentsOf: scan.consumed)

            if scan.token.type == .literal, let length = scan.token.literalLength {
                if length == 0 {
                    pendingLiterals.append([])
                } else {
                    pendingLiteralBytes = length
                    pendingLiteralBuffer.removeAll(keepingCapacity: true)
                }
            }
        }

        return messages
    }
}
