//
// MessageIdList.swift
//
// Helpers for parsing Message-Id style headers (e.g. References, In-Reply-To).
//

import Foundation

public struct MessageIdList: Sendable, Equatable, CustomStringConvertible {
    public let ids: [String]

    public init(_ ids: [String]) {
        self.ids = ids
    }

    public var description: String {
        ids.joined(separator: " ")
    }

    public static func parse(_ value: String) -> MessageIdList? {
        let ids = parseAll(value)
        guard !ids.isEmpty else { return nil }
        return MessageIdList(ids)
    }

    public static func parseAll(_ value: String) -> [String] {
        var results: [String] = []
        var startIndex = value.startIndex

        while let start = value[startIndex...].firstIndex(of: "<") {
            guard let end = value[start...].firstIndex(of: ">"), end > start else {
                break
            }
            let id = String(value[start...end])
            if id.count > 2 {
                results.append(id)
            }
            startIndex = value.index(after: end)
        }

        if results.isEmpty {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                results.append(trimmed)
            }
        }

        return results
    }
}
