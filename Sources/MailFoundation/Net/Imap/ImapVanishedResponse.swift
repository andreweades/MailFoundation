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
// ImapVanishedResponse.swift
//
// Parse QRESYNC VANISHED responses.
//

public struct ImapVanishedResponse: Sendable, Equatable {
    public let earlier: Bool
    public let uids: UniqueIdSet

    public static func parse(_ line: String, validity: UInt32 = 0) -> ImapVanishedResponse? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.uppercased().hasPrefix("* VANISHED") else {
            return nil
        }

        var rest = trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces)
        guard rest.uppercased().hasPrefix("VANISHED") else { return nil }
        rest = rest.dropFirst("VANISHED".count).trimmingCharacters(in: .whitespaces)

        var earlier = false
        if rest.hasPrefix("(") {
            guard let close = rest.firstIndex(of: ")") else { return nil }
            let inner = rest[rest.index(after: rest.startIndex)..<close]
            if inner.uppercased().contains("EARLIER") {
                earlier = true
            }
            rest = rest[rest.index(after: close)...].trimmingCharacters(in: .whitespaces)
        }

        guard let set = try? UniqueIdSet(parsing: String(rest), validity: validity) else {
            return nil
        }
        return ImapVanishedResponse(earlier: earlier, uids: set)
    }
}

public extension ImapVanishedResponse {
    static func == (lhs: ImapVanishedResponse, rhs: ImapVanishedResponse) -> Bool {
        lhs.earlier == rhs.earlier && lhs.uids.description == rhs.uids.description
    }
}
