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
// ImapFetchBodySectionResponse.swift
//
// Parse FETCH BODY[] literal responses.
//

public struct ImapFetchBodySectionResponse: Sendable, Equatable {
    public let sequence: Int
    public let section: ImapFetchBodySection?
    public let peek: Bool
    public let partial: ImapFetchPartial?
    public let data: [UInt8]

    public static func parse(_ message: ImapLiteralMessage) -> ImapFetchBodySectionResponse? {
        guard let literal = message.literal else { return nil }
        guard let fetch = ImapFetchResponse.parse(message.line) else { return nil }
        return parsePayload(fetch.payload, sequence: fetch.sequence, data: literal)
    }

    public static func parsePayload(_ payload: String, sequence: Int, data: [UInt8]) -> ImapFetchBodySectionResponse? {
        let upper = payload.uppercased()
        guard let bodyRange = upper.range(of: "BODY") else { return nil }
        var index = bodyRange.lowerBound
        var peek = false

        if upper[index...].hasPrefix("BODY.PEEK[") {
            peek = true
            index = upper.index(index, offsetBy: "BODY.PEEK[".count)
        } else if upper[index...].hasPrefix("BODY[") {
            index = upper.index(index, offsetBy: "BODY[".count)
        } else {
            return nil
        }

        let startIndex = index
        while index < payload.endIndex, payload[index] != "]" {
            index = payload.index(after: index)
        }
        guard index < payload.endIndex else { return nil }
        let sectionText = String(payload[startIndex..<index])
        let section = sectionText.isEmpty ? nil : ImapFetchBodySection.parse(sectionText)
        index = payload.index(after: index)

        let partial = parsePartial(from: payload[index...])
        return ImapFetchBodySectionResponse(sequence: sequence, section: section, peek: peek, partial: partial, data: data)
    }

    private static func parsePartial(from text: Substring) -> ImapFetchPartial? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "<", let endIndex = trimmed.firstIndex(of: ">") else { return nil }
        let inner = trimmed[trimmed.index(after: trimmed.startIndex)..<endIndex]
        let parts = inner.split(separator: ".", omittingEmptySubsequences: true)
        guard parts.count == 2, let start = Int(parts[0]), let length = Int(parts[1]) else {
            return nil
        }
        return ImapFetchPartial(start: start, length: length)
    }
}
