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
// ImapSelectedStateReducer.swift
//
// Deterministic state reducer for selected mailbox updates.
//

public struct ImapSelectedStateDelta: Sendable, Equatable {
    public let previous: ImapSelectedState
    public let current: ImapSelectedState
    public let qresyncEvents: [ImapQresyncEvent]
    public let flagChanges: [ImapFlagChange]
    public let idleEvents: [ImapIdleEvent]
    public let addedUids: [UniqueId]
    public let removedUids: [UniqueId]

    public init(
        previous: ImapSelectedState,
        current: ImapSelectedState,
        qresyncEvents: [ImapQresyncEvent],
        flagChanges: [ImapFlagChange],
        idleEvents: [ImapIdleEvent],
        addedUids: [UniqueId],
        removedUids: [UniqueId]
    ) {
        self.previous = previous
        self.current = current
        self.qresyncEvents = qresyncEvents
        self.flagChanges = flagChanges
        self.idleEvents = idleEvents
        self.addedUids = addedUids
        self.removedUids = removedUids
    }
}

public enum ImapSelectedStateReducer {
    public static func reduce(
        state: inout ImapSelectedState,
        messages: [ImapLiteralMessage],
        validity: UInt32? = nil,
        mailbox: String? = nil
    ) -> ImapSelectedStateDelta {
        let previous = state
        var qresyncEvents: [ImapQresyncEvent] = []
        var flagChanges: [ImapFlagChange] = []
        var idleEvents: [ImapIdleEvent] = []

        for message in messages {
            if let response = message.response {
                state.apply(response: response)
            } else if let response = ImapResponse.parse(message.line) {
                state.apply(response: response)
            }

            if let idle = ImapIdleEvent.parse(message.line) {
                if case .other = idle {
                    // Ignore non-idle metadata to keep deltas focused.
                } else {
                    idleEvents.append(idle)
                    state.apply(event: idle)
                }
            }

            if let modSeq = ImapModSeqResponse.parse(message.line) {
                state.apply(modSeq: modSeq)
            }

            if let fetch = ImapFetchResponse.parse(message.line) {
                if let attrs = ImapFetchAttributes.parse(message) {
                    state.applyFetch(sequence: fetch.sequence, uid: attrs.uid, modSeq: attrs.modSeq)
                }
                if let change = ImapFlagChange.parse(message) {
                    flagChanges.append(change)
                }
            }

            if let status = ImapStatusResponse.parse(message), let mailbox, status.mailbox == mailbox {
                state.apply(status: status)
            }

            if let listStatus = ImapListStatusResponse.parse(message), let mailbox, listStatus.mailbox.name == mailbox {
                state.apply(listStatus: listStatus)
            }

            let eventValidity = validity ?? state.uidValidity ?? 0
            if let event = ImapQresyncEvent.parse(message, validity: eventValidity) {
                state.apply(event: event)
                qresyncEvents.append(event)
            }
        }

        let before = previous.uidSetSnapshot(sortOrder: .ascending)
        let after = state.uidSetSnapshot(sortOrder: .ascending)
        let beforeSet = Set(before.map { $0 })
        let afterSet = Set(after.map { $0 })
        let added = after.filter { !beforeSet.contains($0) }
        let removed = before.filter { !afterSet.contains($0) }

        return ImapSelectedStateDelta(
            previous: previous,
            current: state,
            qresyncEvents: qresyncEvents,
            flagChanges: flagChanges,
            idleEvents: idleEvents,
            addedUids: added,
            removedUids: removed
        )
    }
}
