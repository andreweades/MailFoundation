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
            if let status = ImapStatusResponse.parse(message.line) {
                state.apply(status: status)
            }
            if let listStatus = ImapListStatusResponse.parse(message.line) {
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
