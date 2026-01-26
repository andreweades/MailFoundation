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
// ThreadingReferences.swift
//
// Helpers for combining References and In-Reply-To headers.
//

public struct ThreadingReferences: Sendable, Equatable, CustomStringConvertible {
    public let ids: [String]

    public init(_ ids: [String]) {
        self.ids = ids
    }

    public var description: String {
        MessageIdList(ids).description
    }

    public static func merge(inReplyTo: String?, references: String?) -> ThreadingReferences? {
        var combined: [String] = []

        if let references {
            combined.append(contentsOf: MessageIdList.parseAll(references))
        }

        if let inReplyTo {
            let ids = MessageIdList.parseAll(inReplyTo)
            for id in ids where !combined.contains(id) {
                combined.append(id)
            }
        }

        guard !combined.isEmpty else { return nil }
        return ThreadingReferences(combined)
    }

    public static func merge(referencesHeader: ReferencesHeader?, inReplyToHeader: InReplyToHeader?) -> ThreadingReferences? {
        let references = referencesHeader?.description
        let inReplyTo = inReplyToHeader?.description
        return merge(inReplyTo: inReplyTo, references: references)
    }
}
