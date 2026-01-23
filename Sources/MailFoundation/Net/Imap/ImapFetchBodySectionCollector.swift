//
// ImapFetchBodySectionCollector.swift
//
// Aggregate BODY[] literal responses per FETCH sequence.
//

public struct ImapFetchBodySectionResult: Sendable, Equatable {
    public let sequence: Int
    public let sections: [ImapFetchBodySectionPayload]

    public func section(
        part: [Int] = [],
        subsection: ImapFetchBodySubsection? = nil
    ) -> ImapFetchBodySectionPayload? {
        sections.first { payload in
            if payload.section == nil {
                return part.isEmpty && subsection == nil
            }
            return payload.section?.part == part && payload.section?.subsection == subsection
        }
    }
}

public struct ImapFetchBodyResult: Sendable, Equatable {
    public let sequence: Int
    public let bodies: [ImapFetchBodySectionPayload]
}

public enum ImapFetchBodyParser {
    public static func parse(_ messages: [ImapLiteralMessage]) -> [ImapFetchBodyResult] {
        var grouped: [Int: [ImapFetchBodySectionPayload]] = [:]
        for message in messages {
            guard let parsed = ImapFetchBodySectionResponse.parse(message) else { continue }
            let payload = ImapFetchBodySectionPayload(
                section: parsed.section,
                peek: parsed.peek,
                partial: parsed.partial,
                data: parsed.data
            )
            grouped[parsed.sequence, default: []].append(payload)
        }
        return grouped.map { ImapFetchBodyResult(sequence: $0.key, bodies: $0.value) }
            .sorted { $0.sequence < $1.sequence }
    }
}

public struct ImapFetchBodySectionPayload: Sendable, Equatable {
    public let section: ImapFetchBodySection?
    public let peek: Bool
    public let partial: ImapFetchPartial?
    public let data: [UInt8]
}

public actor ImapFetchBodySectionCollector {
    private var pending: [Int: [ImapFetchBodySectionPayload]] = [:]

    public init() {}

    public func ingest(_ message: ImapLiteralMessage) -> ImapFetchBodySectionResult? {
        guard let parsed = ImapFetchBodySectionResponse.parse(message) else { return nil }
        let payload = ImapFetchBodySectionPayload(
            section: parsed.section,
            peek: parsed.peek,
            partial: parsed.partial,
            data: parsed.data
        )
        pending[parsed.sequence, default: []].append(payload)
        return nil
    }

    public func ingest(_ messages: [ImapLiteralMessage]) -> [ImapFetchBodySectionResult] {
        var results: [ImapFetchBodySectionResult] = []
        for message in messages {
            _ = ingest(message)
        }
        for (sequence, sections) in pending {
            results.append(ImapFetchBodySectionResult(sequence: sequence, sections: sections))
        }
        pending.removeAll()
        return results.sorted { $0.sequence < $1.sequence }
    }
}
