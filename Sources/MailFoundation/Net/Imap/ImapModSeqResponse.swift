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
// ImapModSeqResponse.swift
//
// Parse CONDSTORE/QRESYNC MODSEQ response codes.
//

public enum ImapModSeqKind: Sendable, Equatable {
    case highest
    case modSeq
}

public struct ImapModSeqResponse: Sendable, Equatable {
    public let kind: ImapModSeqKind
    public let value: UInt64

    public static func parse(_ line: String) -> ImapModSeqResponse? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let open = trimmed.firstIndex(of: "["), let close = trimmed.firstIndex(of: "]"), close > open else {
            return nil
        }
        let inner = trimmed[trimmed.index(after: open)..<close]
        let parts = inner.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2, let value = UInt64(parts[1]) else {
            return nil
        }
        let code = parts[0].uppercased()
        switch code {
        case "HIGHESTMODSEQ":
            return ImapModSeqResponse(kind: .highest, value: value)
        case "MODSEQ":
            return ImapModSeqResponse(kind: .modSeq, value: value)
        default:
            return nil
        }
    }
}
