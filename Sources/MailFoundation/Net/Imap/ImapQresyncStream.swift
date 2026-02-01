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
// ImapQresyncStream.swift
//
// Apply QRESYNC events and response codes to selected state.
//

public actor ImapQresyncStream {
    public private(set) var state: ImapSelectedState

    public init(state: ImapSelectedState = ImapSelectedState()) {
        self.state = state
    }

    public func ingest(messages: [ImapLiteralMessage]) -> [ImapQresyncEvent] {
        var events: [ImapQresyncEvent] = []
        for message in messages {
            if let response = message.response {
                state.apply(response: response)
            } else if let response = ImapResponse.parse(message.line) {
                state.apply(response: response)
            }
            if let modSeq = ImapModSeqResponse.parse(message.line) {
                state.apply(modSeq: modSeq)
            }
            if let status = ImapStatusResponse.parse(message) {
                state.apply(status: status)
            }
            if let listStatus = ImapListStatusResponse.parse(message) {
                state.apply(listStatus: listStatus)
            }
            if let event = ImapQresyncEvent.parse(message, validity: state.uidValidity ?? 0) {
                state.apply(event: event)
                events.append(event)
            }
        }
        return events
    }
}
