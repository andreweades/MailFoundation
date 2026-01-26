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
// ImapFlagChange.swift
//
// Structured FLAG update parsing (typically from UID STORE responses).
//

public struct ImapFlagChange: Sendable, Equatable {
    public let sequence: Int
    public let uid: UInt32?
    public let flags: [String]
    public let modSeq: UInt64?

    public init(sequence: Int, uid: UInt32?, flags: [String], modSeq: UInt64?) {
        self.sequence = sequence
        self.uid = uid
        self.flags = flags
        self.modSeq = modSeq
    }

    public static func parse(_ fetch: ImapFetchResponse) -> ImapFlagChange? {
        let upper = fetch.payload.uppercased()
        guard upper.contains("FLAGS") else { return nil }
        guard let attributes = ImapFetchAttributes.parse(fetch) else { return nil }
        return ImapFlagChange(
            sequence: fetch.sequence,
            uid: attributes.uid,
            flags: attributes.flags,
            modSeq: attributes.modSeq
        )
    }

    public static func parse(_ line: String) -> ImapFlagChange? {
        guard let fetch = ImapFetchResponse.parse(line) else { return nil }
        return parse(fetch)
    }
}
