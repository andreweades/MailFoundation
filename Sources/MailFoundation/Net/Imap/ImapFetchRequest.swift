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
// ImapFetchRequest.swift
//
// IMAP fetch request helpers.
//

import Foundation
import MimeFoundation

public struct FetchRequest: Sendable, Equatable {
    public var items: MessageSummaryItems
    public var headers: HeaderSet?
    public var changedSince: UInt64?
    /// Options that control how preview text is requested.
    public var previewOptions: PreviewOptions

    public init(
        items: MessageSummaryItems = .none,
        headers: HeaderSet? = nil,
        changedSince: UInt64? = nil,
        previewOptions: PreviewOptions = .none
    ) {
        self.items = items
        self.headers = headers
        self.changedSince = changedSince
        self.previewOptions = previewOptions
    }

    public init(
        items: MessageSummaryItems = .none,
        headers: [HeaderId],
        changedSince: UInt64? = nil,
        previewOptions: PreviewOptions = .none
    ) throws {
        self.items = items
        self.headers = try HeaderSet(headers: headers)
        self.changedSince = changedSince
        self.previewOptions = previewOptions
    }

    public init(
        items: MessageSummaryItems = .none,
        headers: [String],
        changedSince: UInt64? = nil,
        previewOptions: PreviewOptions = .none
    ) throws {
        self.items = items
        self.headers = try HeaderSet(headers: headers)
        self.changedSince = changedSince
        self.previewOptions = previewOptions
    }

    public var imapItemList: String {
        imapItemList(previewFallback: nil)
    }

    public func imapItemList(previewFallback: ImapFetchPartial? = nil) -> String {
        var tokens = items.imapTokens(includePreview: previewFallback == nil, previewOptions: previewOptions)
        if let headerToken = headerFetchToken(headers: headers, requestHeaders: items.contains(.headers), requestReferences: items.contains(.references)) {
            tokens.append(headerToken)
        }
        if let previewFallback {
            tokens.append(ImapFetchBody.section(.text, peek: true, partial: previewFallback))
        }

        guard !tokens.isEmpty else { return "()" }
        if tokens.count == 1 { return tokens[0] }
        return "(\(tokens.joined(separator: " ")))"
    }

    private func headerFetchToken(headers: HeaderSet?, requestHeaders: Bool, requestReferences: Bool) -> String? {
        if let headers {
            if isEmptyExclude(headers: headers, requestReferences: requestReferences) {
                return "BODY.PEEK[HEADER]"
            }

            if headers.exclude {
                var fieldList = headers.orderedHeaders
                if requestReferences {
                    fieldList.removeAll { $0 == "REFERENCES" }
                }
                if fieldList.isEmpty {
                    return "BODY.PEEK[HEADER]"
                }
                return "BODY.PEEK[HEADER.FIELDS.NOT (\(fieldList.joined(separator: " ")))]"
            }

            var fieldList = headers.orderedHeaders
            if requestReferences, !headers.contains("REFERENCES") {
                fieldList.append("REFERENCES")
            }
            if fieldList.isEmpty {
                return requestHeaders ? "BODY.PEEK[HEADER]" : nil
            }

            return "BODY.PEEK[HEADER.FIELDS (\(fieldList.joined(separator: " ")))]"
        }

        if requestHeaders {
            return "BODY.PEEK[HEADER]"
        }

        if requestReferences {
            return "BODY.PEEK[HEADER.FIELDS (REFERENCES)]"
        }

        return nil
    }

    private func isEmptyExclude(headers: HeaderSet, requestReferences: Bool) -> Bool {
        if !headers.exclude { return false }
        if headers.count == 0 { return true }
        if headers.count == 1, requestReferences, headers.contains("REFERENCES") {
            return true
        }
        return false
    }
}

private extension MessageSummaryItems {
    func imapTokens(includePreview: Bool, previewOptions: PreviewOptions) -> [String] {
        var tokens: [String] = []

        if contains(.annotations) { tokens.append("ANNOTATION") }
        if contains(.body) { tokens.append("BODY") }
        if contains(.bodyStructure) { tokens.append("BODYSTRUCTURE") }
        if contains(.envelope) { tokens.append("ENVELOPE") }
        if contains(.flags) { tokens.append("FLAGS") }
        if contains(.internalDate) { tokens.append("INTERNALDATE") }
        if contains(.size) { tokens.append("RFC822.SIZE") }
        if contains(.modSeq) { tokens.append("MODSEQ") }
        if contains(.uniqueId) { tokens.append("UID") }
        if contains(.emailId) { tokens.append("EMAILID") }
        if contains(.threadId) { tokens.append("THREADID") }
        if contains(.gmailMessageId) { tokens.append("X-GM-MSGID") }
        if contains(.gmailThreadId) { tokens.append("X-GM-THRID") }
        if contains(.gmailLabels) { tokens.append("X-GM-LABELS") }
        if includePreview, contains(.previewText) {
            switch previewOptions {
            case .lazy:
                tokens.append("PREVIEW (LAZY)")
            case .none:
                tokens.append("PREVIEW")
            }
        }
        if contains(.saveDate) { tokens.append("SAVEDATE") }

        return tokens
    }
}

/// Options that control how preview text is fetched.
public enum PreviewOptions: Sendable, Equatable {
    /// Fetch previews normally (PREVIEW).
    case none
    /// Fetch previews lazily (PREVIEW (LAZY)) when supported by the server.
    case lazy
}
