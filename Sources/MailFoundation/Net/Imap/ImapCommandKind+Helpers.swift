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
// ImapCommandKind+Helpers.swift
//
// Convenience helpers for IMAP commands.
//

public extension ImapCommandKind {
    static func namespace() -> ImapCommandKind {
        .namespace
    }

    static func id(_ parameters: [String: String?]? = nil) -> ImapCommandKind {
        .id(ImapId.buildArguments(parameters))
    }

    static func fetch(_ set: SequenceSet, items: String) -> ImapCommandKind {
        .fetch(set.description, items)
    }

    static func store(_ set: SequenceSet, data: String) -> ImapCommandKind {
        .store(set.description, data)
    }

    static func uidFetch(_ set: UniqueIdSet, items: String) -> ImapCommandKind {
        .uidFetch(set.description, items)
    }

    static func uidStore(_ set: UniqueIdSet, data: String) -> ImapCommandKind {
        .uidStore(set.description, data)
    }

    static func copy(_ set: SequenceSet, mailbox: String) -> ImapCommandKind {
        .copy(set.description, mailbox)
    }

    static func uidCopy(_ set: UniqueIdSet, mailbox: String) -> ImapCommandKind {
        .uidCopy(set.description, mailbox)
    }

    static func move(_ set: SequenceSet, mailbox: String) -> ImapCommandKind {
        .move(set.description, mailbox)
    }

    static func uidMove(_ set: UniqueIdSet, mailbox: String) -> ImapCommandKind {
        .uidMove(set.description, mailbox)
    }

    static func search(_ query: SearchQuery) -> ImapCommandKind {
        .search(query.optimized().serialize())
    }

    static func sort(_ query: SearchQuery, orderBy: [OrderBy], charset: String = "UTF-8") throws -> ImapCommandKind {
        let criteria = try ImapSort.buildArguments(orderBy: orderBy, query: query, charset: charset)
        return .sort(criteria)
    }

    static func uidSearch(_ query: SearchQuery) -> ImapCommandKind {
        .uidSearch(query.optimized().serialize())
    }

    static func uidSort(_ query: SearchQuery, orderBy: [OrderBy], charset: String = "UTF-8") throws -> ImapCommandKind {
        let criteria = try ImapSort.buildArguments(orderBy: orderBy, query: query, charset: charset)
        return .uidSort(criteria)
    }

    static func listExtended(reference: String, mailbox: String, returns: [ImapListReturnOption]) -> ImapCommandKind {
        .listExtended(reference, mailbox, returns: returns)
    }

    // NOTE: notify/compress helpers intentionally omitted to avoid overlapping
    // enum-case constructors.
}
