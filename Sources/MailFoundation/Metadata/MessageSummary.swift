//
// MessageSummary.swift
//
// Ported from MailKit (C#) to Swift.
//

import Foundation

public struct MessageSummary: Sendable, Equatable {
    public let sequence: Int
    public let uniqueId: UniqueId?
    public let flags: MessageFlags
    public let keywords: [String]
    public let internalDate: String?
    public let size: Int?
    public let modSeq: UInt64?
    public let envelope: ImapEnvelope?
    public let bodyStructure: ImapBodyStructure?
    public let body: ImapBodyStructure?
    public let items: MessageSummaryItems

    public var index: Int {
        sequence > 0 ? sequence - 1 : 0
    }

    public init(
        sequence: Int,
        items: MessageSummaryItems = .none,
        uniqueId: UniqueId? = nil,
        flags: MessageFlags = [],
        keywords: [String] = [],
        internalDate: String? = nil,
        size: Int? = nil,
        modSeq: UInt64? = nil,
        envelope: ImapEnvelope? = nil,
        bodyStructure: ImapBodyStructure? = nil,
        body: ImapBodyStructure? = nil
    ) {
        self.sequence = sequence
        self.uniqueId = uniqueId
        self.flags = flags
        self.keywords = keywords
        self.internalDate = internalDate
        self.size = size
        self.modSeq = modSeq
        self.envelope = envelope
        self.bodyStructure = bodyStructure
        self.body = body
        self.items = items
    }

    public init?(fetch: ImapFetchResponse) {
        guard let attributes = ImapFetchAttributes.parse(fetch) else { return nil }

        var items: MessageSummaryItems = []

        if !attributes.flags.isEmpty { items.insert(.flags) }
        if let uid = attributes.uid, uid > 0 { items.insert(.uniqueId) }
        if attributes.internalDate != nil { items.insert(.internalDate) }
        if attributes.size != nil { items.insert(.size) }
        if attributes.modSeq != nil { items.insert(.modSeq) }
        if attributes.envelopeRaw != nil { items.insert(.envelope) }
        if attributes.bodyStructure != nil { items.insert(.bodyStructure) }
        if attributes.body != nil { items.insert(.body) }

        let parsedFlags = MessageFlags.parse(attributes.flags)
        let uniqueId = attributes.uid.flatMap { $0 > 0 ? UniqueId(id: $0) : nil }

        self.sequence = fetch.sequence
        self.uniqueId = uniqueId
        self.flags = parsedFlags.flags
        self.keywords = parsedFlags.keywords
        self.internalDate = attributes.internalDate
        self.size = attributes.size
        self.modSeq = attributes.modSeq
        self.envelope = attributes.parsedImapEnvelope()
        self.bodyStructure = attributes.parsedBodyStructure()
        self.body = attributes.body.flatMap(ImapBodyStructure.parse)
        self.items = items
    }
}
