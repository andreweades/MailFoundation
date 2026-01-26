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
// ImapStatusResponse.swift
//
// IMAP STATUS response parsing helpers.
//

public struct ImapStatusResponse: Sendable, Equatable {
    public let mailbox: String
    public let items: [String: Int]

    public static func parse(_ line: String) -> ImapStatusResponse? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.uppercased().hasPrefix("* STATUS ") else {
            return nil
        }

        let restStart = trimmed.index(trimmed.startIndex, offsetBy: 9)
        let rest = trimmed[restStart...]
        guard let openParen = rest.firstIndex(of: "("), let closeParen = rest.firstIndex(of: ")"), closeParen > openParen else {
            return nil
        }

        let mailboxPart = rest[..<openParen].trimmingCharacters(in: .whitespaces)
        let itemsPart = rest[rest.index(after: openParen)..<closeParen]
        let tokens = itemsPart.split(separator: " ", omittingEmptySubsequences: true)
        guard tokens.count >= 2 else { return nil }

        var items: [String: Int] = [:]
        var index = 0
        while index + 1 < tokens.count {
            let key = tokens[index].uppercased()
            let value = Int(tokens[index + 1]) ?? 0
            items[key] = value
            index += 2
        }

        return ImapStatusResponse(mailbox: String(mailboxPart), items: items)
    }
}
