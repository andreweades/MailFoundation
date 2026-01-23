//
// ReferencesHeader.swift
//
// Parser for References header values.
//

public struct ReferencesHeader: Sendable, Equatable, CustomStringConvertible {
    public let ids: [String]

    public init(_ ids: [String]) {
        self.ids = ids
    }

    public var description: String {
        ids.joined(separator: " ")
    }

    public static func parse(_ value: String) -> ReferencesHeader? {
        let ids = MessageIdList.parseAll(value)
        guard !ids.isEmpty else { return nil }
        return ReferencesHeader(ids)
    }
}
