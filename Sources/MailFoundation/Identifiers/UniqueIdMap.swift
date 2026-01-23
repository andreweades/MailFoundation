//
// UniqueIdMap.swift
//
// Ported from MailKit (C#) to Swift.
//

public struct UniqueIdMap: Sendable, Sequence {
    public static let empty = UniqueIdMap(source: [], destination: [])

    public let source: [UniqueId]
    public let destination: [UniqueId]

    public init(source: [UniqueId], destination: [UniqueId]) {
        self.source = source
        self.destination = destination
    }

    public var count: Int {
        source.count
    }

    public var pairedCount: Int {
        Swift.min(source.count, destination.count)
    }

    public var isEmpty: Bool {
        source.isEmpty || destination.isEmpty
    }

    public var keys: [UniqueId] {
        source
    }

    public var values: [UniqueId] {
        destination
    }

    public var pairs: [(UniqueId, UniqueId)] {
        let count = pairedCount
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            (source[index], destination[index])
        }
    }

    public func toDictionary() -> [UniqueId: UniqueId] {
        var dict: [UniqueId: UniqueId] = [:]
        for (key, value) in pairs {
            dict[key] = value
        }
        return dict
    }

    public func contains(_ key: UniqueId) -> Bool {
        source.contains(key)
    }

    public func value(for key: UniqueId) -> UniqueId? {
        guard let index = source.firstIndex(of: key) else {
            return nil
        }
        guard index < destination.count else {
            return nil
        }
        return destination[index]
    }

    public subscript(key: UniqueId) -> UniqueId {
        guard let value = value(for: key) else {
            preconditionFailure("UniqueIdMap does not contain the specified key.")
        }
        return value
    }

    public func makeIterator() -> AnyIterator<(UniqueId, UniqueId)> {
        var index = 0
        return AnyIterator {
            guard index < source.count, index < destination.count else {
                return nil
            }
            let pair = (source[index], destination[index])
            index += 1
            return pair
        }
    }
}
