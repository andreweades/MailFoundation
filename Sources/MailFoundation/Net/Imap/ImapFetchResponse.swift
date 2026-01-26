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
// ImapFetchResponse.swift
//
// IMAP FETCH response parsing helpers.
//

public struct ImapFetchResponse: Sendable, Equatable {
    public let sequence: Int
    public let payload: String

    public static func parse(_ line: String) -> ImapFetchResponse? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.uppercased().hasPrefix("* ") else { return nil }
        let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count == 3, parts[0] == "*", let sequence = Int(parts[1]) else {
            return nil
        }
        let payload = String(parts[2])
        guard payload.uppercased().hasPrefix("FETCH") else { return nil }
        let payloadStart = payload.index(payload.startIndex, offsetBy: 5)
        let trimmedPayload = payload[payloadStart...].trimmingCharacters(in: .whitespaces)
        return ImapFetchResponse(sequence: sequence, payload: String(trimmedPayload))
    }
}
