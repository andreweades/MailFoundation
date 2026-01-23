//
// InReplyToHeader.swift
//
// Parser for In-Reply-To header values.
//

public struct InReplyToHeader: Sendable, Equatable, CustomStringConvertible {
    public let ids: [String]

    public init(_ ids: [String]) {
        self.ids = ids
    }

    public var description: String {
        ids.joined(separator: " ")
    }

    public static func parse(_ value: String) -> InReplyToHeader? {
        let ids = MessageIdList.parseAll(value)
        guard !ids.isEmpty else { return nil }
        return InReplyToHeader(ids)
    }
}
