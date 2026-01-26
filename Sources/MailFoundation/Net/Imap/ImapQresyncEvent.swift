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
// ImapQresyncEvent.swift
//
// QRESYNC event parsing helpers.
//

public struct ImapFetchModSeqEvent: Sendable, Equatable {
    public let sequence: Int
    public let uid: UInt32?
    public let modSeq: UInt64
}

public enum ImapQresyncEvent: Sendable, Equatable {
    case vanished(ImapVanishedResponse)
    case fetch(ImapFetchModSeqEvent)
}

public extension ImapQresyncEvent {
    static func parse(_ line: String, validity: UInt32 = 0) -> ImapQresyncEvent? {
        if let vanished = ImapVanishedResponse.parse(line, validity: validity) {
            return .vanished(vanished)
        }
        if let fetch = ImapFetchResponse.parse(line),
           let attrs = ImapFetchAttributes.parse(fetch),
           let modSeq = attrs.modSeq {
            return .fetch(ImapFetchModSeqEvent(sequence: fetch.sequence, uid: attrs.uid, modSeq: modSeq))
        }
        return nil
    }

    static func parse(_ message: ImapLiteralMessage, validity: UInt32 = 0) -> ImapQresyncEvent? {
        parse(message.line, validity: validity)
    }
}
