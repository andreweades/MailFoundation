//
// ImapSelectedState.swift
//
// Track selected mailbox state (UIDNEXT/UIDVALIDITY/HIGHESTMODSEQ).
//

public struct ImapSelectedState: Sendable, Equatable {
    public var uidNext: UInt32?
    public var uidValidity: UInt32?
    public var highestModSeq: UInt64?

    public init(uidNext: UInt32? = nil, uidValidity: UInt32? = nil, highestModSeq: UInt64? = nil) {
        self.uidNext = uidNext
        self.uidValidity = uidValidity
        self.highestModSeq = highestModSeq
    }

    public mutating func apply(response: ImapResponse) {
        let codes = ImapResponseCode.parseAll(response.text)
        for code in codes {
            switch code.kind {
            case .uidNext(let value):
                uidNext = value
            case .uidValidity(let value):
                uidValidity = value
            case .highestModSeq(let value):
                highestModSeq = max(highestModSeq ?? 0, value)
            }
        }
    }

    public mutating func apply(status: ImapStatusResponse) {
        uidNext = extractUInt32(status.items, key: "UIDNEXT") ?? uidNext
        uidValidity = extractUInt32(status.items, key: "UIDVALIDITY") ?? uidValidity
        if let modSeq = extractUInt64(status.items, key: "HIGHESTMODSEQ") {
            highestModSeq = max(highestModSeq ?? 0, modSeq)
        }
    }

    public mutating func apply(listStatus: ImapListStatusResponse) {
        uidNext = extractUInt32(listStatus.statusItems, key: "UIDNEXT") ?? uidNext
        uidValidity = extractUInt32(listStatus.statusItems, key: "UIDVALIDITY") ?? uidValidity
        if let modSeq = extractUInt64(listStatus.statusItems, key: "HIGHESTMODSEQ") {
            highestModSeq = max(highestModSeq ?? 0, modSeq)
        }
    }

    public mutating func apply(modSeq: ImapModSeqResponse) {
        highestModSeq = max(highestModSeq ?? 0, modSeq.value)
    }

    public mutating func apply(event: ImapQresyncEvent) {
        if case let .fetch(fetch) = event {
            highestModSeq = max(highestModSeq ?? 0, fetch.modSeq)
        }
    }

    private func extractUInt32(_ items: [String: Int], key: String) -> UInt32? {
        guard let value = items[key] else { return nil }
        return UInt32(value)
    }

    private func extractUInt64(_ items: [String: Int], key: String) -> UInt64? {
        guard let value = items[key] else { return nil }
        return UInt64(value)
    }
}
