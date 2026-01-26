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
// ImapESearchResponse.swift
//
// IMAP ESEARCH response parsing helpers.
//

public struct ImapESearchResponse: Sendable, Equatable {
    public let ids: [UInt32]
    public let count: Int?
    public let min: UInt32?
    public let max: UInt32?
    public let isUid: Bool

    public static func parse(_ line: String) -> ImapESearchResponse? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 9 else { return nil }
        let upper = trimmed.uppercased()
        guard upper.hasPrefix("* ESEARCH") else { return nil }

        let startIndex = trimmed.index(trimmed.startIndex, offsetBy: 9)
        let remainder = trimmed[startIndex...].trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = tokenize(String(remainder))
        if tokens.isEmpty { return ImapESearchResponse(ids: [], count: nil, min: nil, max: nil, isUid: false) }

        var index = 0

        if index < tokens.count, tokens[index] == "(" {
            index += 1
            while index < tokens.count, tokens[index] != ")" {
                index += 1
            }
            if index < tokens.count, tokens[index] == ")" {
                index += 1
            }
        }

        var isUid = false
        if index < tokens.count, tokens[index].caseInsensitiveEquals("UID") {
            isUid = true
            index += 1
        }

        var ids: [UInt32] = []
        var count: Int?
        var minValue: UInt32?
        var maxValue: UInt32?

        while index < tokens.count {
            let key = tokens[index].uppercased()
            index += 1
            guard index < tokens.count else { break }
            let value = tokens[index]
            index += 1

            switch key {
            case "ALL":
                if let set = try? SequenceSet(parsing: value) {
                    ids = Array(set)
                }
            case "COUNT":
                if let parsed = Int(value) {
                    count = parsed
                }
            case "MIN":
                if let parsed = UInt32(value) {
                    minValue = parsed
                }
            case "MAX":
                if let parsed = UInt32(value) {
                    maxValue = parsed
                }
            default:
                continue
            }
        }

        return ImapESearchResponse(ids: ids, count: count, min: minValue, max: maxValue, isUid: isUid)
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
            if ch == "(" || ch == ")" {
                tokens.append(String(ch))
                index = text.index(after: index)
                continue
            }
            if ch == "\"" {
                index = text.index(after: index)
                var value = ""
                while index < text.endIndex {
                    let current = text[index]
                    if current == "\\" {
                        let next = text.index(after: index)
                        if next < text.endIndex {
                            value.append(text[next])
                            index = text.index(after: next)
                        } else {
                            index = next
                        }
                        continue
                    }
                    if current == "\"" {
                        index = text.index(after: index)
                        break
                    }
                    value.append(current)
                    index = text.index(after: index)
                }
                tokens.append(value)
                continue
            }

            let start = index
            while index < text.endIndex {
                let current = text[index]
                if current.isWhitespace || current == "(" || current == ")" {
                    break
                }
                index = text.index(after: index)
            }
            tokens.append(String(text[start..<index]))
        }

        return tokens
    }
}

private extension String {
    func caseInsensitiveEquals(_ other: String) -> Bool {
        compare(other, options: [.caseInsensitive]) == .orderedSame
    }
}
