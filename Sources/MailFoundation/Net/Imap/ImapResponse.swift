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
// ImapResponse.swift
//
// Basic IMAP response model.
//

import Foundation

public enum ImapResponseKind: Sendable, Equatable {
    case untagged
    case tagged(String)
    case continuation
}

public enum ImapResponseStatus: String, Sendable {
    case ok = "OK"
    case no = "NO"
    case bad = "BAD"
    case preauth = "PREAUTH"
    case bye = "BYE"
}

public struct ImapResponse: Sendable, Equatable {
    public let kind: ImapResponseKind
    public let status: ImapResponseStatus?
    public let text: String

    public var isOk: Bool {
        status == .ok
    }

    public static func parse(_ line: String) -> ImapResponse? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("+") {
            let message = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            return ImapResponse(kind: .continuation, status: nil, text: String(message))
        }

        let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard let first = parts.first else { return nil }

        let kind: ImapResponseKind
        if first == "*" {
            kind = .untagged
        } else {
            kind = .tagged(String(first))
        }

        let statusIndex = first == "*" ? 1 : 1
        guard parts.count > statusIndex else {
            return ImapResponse(kind: kind, status: nil, text: "")
        }

        let statusToken = String(parts[statusIndex])
        let status = ImapResponseStatus(rawValue: statusToken)
        let text: String
        if parts.count > statusIndex + 1 {
            text = String(parts[statusIndex + 1])
        } else {
            text = ""
        }

        return ImapResponse(kind: kind, status: status, text: text)
    }
}
