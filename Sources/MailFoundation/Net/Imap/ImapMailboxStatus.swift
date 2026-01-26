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
// ImapMailboxStatus.swift
//
// Unified mailbox status model.
//

public struct ImapMailboxStatus: Sendable, Equatable {
    public let name: String
    public let mailbox: ImapMailbox?
    public let items: [String: Int]

    public init(name: String, mailbox: ImapMailbox? = nil, items: [String: Int]) {
        self.name = name
        self.mailbox = mailbox
        self.items = items
    }

    public init(status: ImapStatusResponse) {
        self.init(name: status.mailbox, mailbox: nil, items: status.items)
    }

    public init(listStatus: ImapListStatusResponse) {
        self.init(name: listStatus.mailbox.name, mailbox: listStatus.mailbox, items: listStatus.statusItems)
    }

    public func merging(_ other: ImapMailboxStatus) -> ImapMailboxStatus {
        var mergedItems = items
        for (key, value) in other.items {
            mergedItems[key] = value
        }
        return ImapMailboxStatus(
            name: name,
            mailbox: mailbox ?? other.mailbox,
            items: mergedItems
        )
    }
}
