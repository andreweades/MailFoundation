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
// ImapSearchResponse.swift
//
// IMAP SEARCH response parsing helpers.
//

public struct ImapSearchResponse: Sendable, Equatable {
    public let ids: [UInt32]
    public let count: Int?
    public let min: UInt32?
    public let max: UInt32?
    public let isUid: Bool

    public init(
        ids: [UInt32],
        count: Int? = nil,
        min: UInt32? = nil,
        max: UInt32? = nil,
        isUid: Bool = false
    ) {
        self.ids = ids
        self.count = count
        self.min = min
        self.max = max
        self.isUid = isUid
    }

    public init(esearch: ImapESearchResponse, defaultIsUid: Bool = false) {
        self.ids = esearch.ids
        self.count = esearch.count
        self.min = esearch.min
        self.max = esearch.max
        self.isUid = esearch.isUid || defaultIsUid
    }

    public static func parse(_ line: String) -> ImapSearchResponse? {
        var reader = ImapLineTokenReader(line: line)
        guard let token = reader.readToken(), token.type == .asterisk else { return nil }
        guard let commandToken = reader.readToken(),
              commandToken.type == .atom,
              let command = commandToken.stringValue else {
            return nil
        }
        let upper = command.uppercased()
        guard upper == "SEARCH" || upper == "SORT" else { return nil }

        var ids: [UInt32] = []
        while let valueToken = reader.readToken() {
            if let value = valueToken.stringValue, let id = UInt32(value) {
                ids.append(id)
            }
        }
        return ImapSearchResponse(ids: ids)
    }
}

public enum ImapSearchIdSet: Sendable {
    case sequence(SequenceSet)
    case uid(UniqueIdSet)
}

public extension ImapSearchResponse {
    func sequenceSet() -> SequenceSet {
        SequenceSet(ids.map { Int($0) })
    }

    func uniqueIdSet(validity: UInt32 = 0) -> UniqueIdSet {
        let uniqueIds = ids.compactMap { try? UniqueId(parsing: String($0), validity: validity) }
        var set = UniqueIdSet(validity: validity)
        set.add(contentsOf: uniqueIds)
        return set
    }

    func idSet(validity: UInt32 = 0) -> ImapSearchIdSet {
        if isUid {
            return .uid(uniqueIdSet(validity: validity))
        }
        return .sequence(sequenceSet())
    }
}
