//
// OrderBy.swift
//
// Ported from MailKit (C#) to Swift.
//

public enum OrderByError: Error, Sendable, Equatable {
    case invalidSortOrder
}

public struct OrderByAnnotation: Sendable, Equatable {
    public let entry: String
    public let attribute: String

    public init(entry: String, attribute: String) {
        self.entry = entry
        self.attribute = attribute
    }
}

public struct OrderBy: Sendable, Equatable {
    public let type: OrderByType
    public let order: SortOrder
    public let annotation: OrderByAnnotation?

    public init(type: OrderByType, order: SortOrder) throws {
        guard order != .none else { throw OrderByError.invalidSortOrder }
        self.type = type
        self.order = order
        self.annotation = nil
    }

    public init(annotation: OrderByAnnotation, order: SortOrder) throws {
        guard order != .none else { throw OrderByError.invalidSortOrder }
        self.type = .annotation
        self.order = order
        self.annotation = annotation
    }
}

public extension OrderBy {
    static let arrival = try! OrderBy(type: .arrival, order: .ascending)
    static let reverseArrival = try! OrderBy(type: .arrival, order: .descending)

    static let cc = try! OrderBy(type: .cc, order: .ascending)
    static let reverseCc = try! OrderBy(type: .cc, order: .descending)

    static let date = try! OrderBy(type: .date, order: .ascending)
    static let reverseDate = try! OrderBy(type: .date, order: .descending)

    static let from = try! OrderBy(type: .from, order: .ascending)
    static let reverseFrom = try! OrderBy(type: .from, order: .descending)

    static let displayFrom = try! OrderBy(type: .displayFrom, order: .ascending)
    static let reverseDisplayFrom = try! OrderBy(type: .displayFrom, order: .descending)

    static let size = try! OrderBy(type: .size, order: .ascending)
    static let reverseSize = try! OrderBy(type: .size, order: .descending)

    static let subject = try! OrderBy(type: .subject, order: .ascending)
    static let reverseSubject = try! OrderBy(type: .subject, order: .descending)

    static let to = try! OrderBy(type: .to, order: .ascending)
    static let reverseTo = try! OrderBy(type: .to, order: .descending)

    static let displayTo = try! OrderBy(type: .displayTo, order: .ascending)
    static let reverseDisplayTo = try! OrderBy(type: .displayTo, order: .descending)

    static func annotation(entry: String, attribute: String, order: SortOrder) throws -> OrderBy {
        try OrderBy(annotation: OrderByAnnotation(entry: entry, attribute: attribute), order: order)
    }
}
