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

        var reader = ImapLineTokenReader(line: trimmed)
        guard let first = reader.readToken() else { return nil }

        let kind: ImapResponseKind
        switch first.type {
        case .asterisk:
            kind = .untagged
        case .atom:
            guard let tag = first.stringValue else { return nil }
            kind = .tagged(tag)
        default:
            return nil
        }

        guard let statusToken = reader.readToken() else {
            return ImapResponse(kind: kind, status: nil, text: "")
        }

        let statusValue = statusToken.stringValue ?? ""
        let status = ImapResponseStatus(rawValue: statusValue)
        let text = reader.remainingString(trimLeadingWhitespace: true)
        return ImapResponse(kind: kind, status: status, text: text)
    }
}
