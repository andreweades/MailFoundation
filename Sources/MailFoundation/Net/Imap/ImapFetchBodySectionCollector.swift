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

public struct ImapFetchBodyKey: Sendable, Hashable {
    public let section: String
    public let peek: Bool
    public let partial: ImapFetchPartial?

    public init(section: String, peek: Bool, partial: ImapFetchPartial?) {
        self.section = section
        self.peek = peek
        self.partial = partial
    }
}

public struct ImapFetchBodyMap: Sendable, Equatable {
    public let sequence: Int
    public let payloads: [ImapFetchBodySectionPayload]
    public let bodies: [ImapFetchBodyKey: [UInt8]]

    public func body(section: ImapFetchBodySection? = nil) -> [UInt8]? {
        let key = section?.serialize() ?? ""
        return bodies.first { $0.key.section == key }?.value
    }
}

public struct ImapFetchBodyQresyncResult: Sendable, Equatable {
    public let bodies: [ImapFetchBodyMap]
    public let qresyncEvents: [ImapQresyncEvent]
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

    public static func parseMaps(_ messages: [ImapLiteralMessage]) -> [ImapFetchBodyMap] {
        maps(from: parse(messages))
    }

    public static func parseMapsWithQresync(_ messages: [ImapLiteralMessage], validity: UInt32 = 0) -> ImapFetchBodyQresyncResult {
        let bodies = parseMaps(messages)
        var events: [ImapQresyncEvent] = []
        for message in messages {
            if let event = ImapQresyncEvent.parse(message, validity: validity) {
                events.append(event)
            }
        }
        return ImapFetchBodyQresyncResult(bodies: bodies, qresyncEvents: events)
    }

    public static func maps(from results: [ImapFetchBodyResult]) -> [ImapFetchBodyMap] {
        results.map { result in
            var map: [ImapFetchBodyKey: [UInt8]] = [:]
            for payload in result.bodies {
                let key = ImapFetchBodyKey(
                    section: payload.section?.serialize() ?? "",
                    peek: payload.peek,
                    partial: payload.partial
                )
                map[key] = payload.data
            }
            return ImapFetchBodyMap(sequence: result.sequence, payloads: result.bodies, bodies: map)
        }
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

    public func ingestWithQresync(_ messages: [ImapLiteralMessage], validity: UInt32 = 0) -> ImapFetchBodyQresyncResult {
        let results = ingest(messages)
        let bodies = ImapFetchBodyParser.maps(from: results.map {
            ImapFetchBodyResult(sequence: $0.sequence, bodies: $0.sections)
        })
        var events: [ImapQresyncEvent] = []
        for message in messages {
            if let event = ImapQresyncEvent.parse(message, validity: validity) {
                events.append(event)
            }
        }
        return ImapFetchBodyQresyncResult(bodies: bodies, qresyncEvents: events)
    }
}
