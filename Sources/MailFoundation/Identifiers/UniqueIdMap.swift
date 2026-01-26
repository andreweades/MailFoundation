//
// Author: Jeffrey Stedfast <jestedfa@microsoft.com>
//
// Copyright (c) 2013-2026 .NET Foundation and Contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

//
// UniqueIdMap.swift
//
// Ported from MailKit (C#) to Swift.
//

/// A mapping of unique identifiers from one folder to another.
///
/// A `UniqueIdMap` is used to discover the mapping of one set of unique identifiers
/// to another. This is particularly useful when copying or moving messages from one
/// folder to another, where you want to know what the unique identifiers are for
/// each of the messages in the destination folder.
///
/// The map maintains parallel arrays of source and destination unique identifiers,
/// where each source identifier at index `i` maps to the destination identifier
/// at the same index.
///
/// ## Example
///
/// ```swift
/// // After copying messages, create a map of source to destination UIDs
/// let sourceUids = [UniqueId(id: 1), UniqueId(id: 2), UniqueId(id: 3)]
/// let destUids = [UniqueId(id: 100), UniqueId(id: 101), UniqueId(id: 102)]
/// let map = UniqueIdMap(source: sourceUids, destination: destUids)
///
/// // Look up the destination UID for a source UID
/// if let destUid = map.value(for: UniqueId(id: 2)) {
///     print("Message 2 was copied to UID \(destUid.id)") // "Message 2 was copied to UID 101"
/// }
///
/// // Iterate over all mappings
/// for (source, destination) in map {
///     print("\(source.id) -> \(destination.id)")
/// }
/// ```
public struct UniqueIdMap: Sendable, Sequence {
    /// An empty mapping of unique identifiers.
    ///
    /// Use this constant instead of creating a new empty map for better efficiency.
    public static let empty = UniqueIdMap(source: [], destination: [])

    /// The list of unique identifiers from the source folder.
    ///
    /// Each identifier at index `i` maps to the identifier at the same index
    /// in the `destination` array.
    public let source: [UniqueId]

    /// The list of unique identifiers in the destination folder.
    ///
    /// Each identifier at index `i` corresponds to the source identifier at
    /// the same index in the `source` array.
    public let destination: [UniqueId]

    /// Creates a new unique identifier map from parallel arrays of source and destination identifiers.
    ///
    /// - Parameters:
    ///   - source: The unique identifiers from the source folder.
    ///   - destination: The corresponding unique identifiers in the destination folder.
    ///
    /// - Note: The arrays do not need to be the same length. When iterating or accessing
    ///   pairs, only indices valid in both arrays are used.
    public init(source: [UniqueId], destination: [UniqueId]) {
        self.source = source
        self.destination = destination
    }

    /// Creates a new unique identifier map from an array of (source, destination) pairs.
    ///
    /// - Parameter pairs: An array of tuples where each tuple contains a source
    ///   unique identifier and its corresponding destination unique identifier.
    public init(pairs: [(UniqueId, UniqueId)]) {
        self.source = pairs.map { $0.0 }
        self.destination = pairs.map { $0.1 }
    }

    /// Creates a new unique identifier map from a dictionary.
    ///
    /// - Parameters:
    ///   - dictionary: A dictionary mapping source unique identifiers to destination
    ///     unique identifiers.
    ///   - sortedByKey: If `true` (the default), the map entries are sorted by the
    ///     source unique identifier. If `false`, the order is undefined.
    public init(dictionary: [UniqueId: UniqueId], sortedByKey: Bool = true) {
        if sortedByKey {
            let keys = dictionary.keys.sorted()
            self.source = keys
            self.destination = keys.compactMap { dictionary[$0] }
        } else {
            self.source = Array(dictionary.keys)
            self.destination = Array(dictionary.values)
        }
    }

    /// The number of source unique identifiers in the map.
    ///
    /// This is the count of the `source` array. To get the number of valid pairs,
    /// use `pairedCount` instead.
    public var count: Int {
        source.count
    }

    /// The number of valid (source, destination) pairs in the map.
    ///
    /// This is the minimum of the `source` and `destination` array counts.
    public var pairedCount: Int {
        Swift.min(source.count, destination.count)
    }

    /// Indicates whether the map contains no valid pairs.
    ///
    /// Returns `true` if either the source or destination array is empty.
    public var isEmpty: Bool {
        source.isEmpty || destination.isEmpty
    }

    /// The source unique identifiers in the map.
    ///
    /// This is equivalent to accessing the `source` property directly.
    public var keys: [UniqueId] {
        source
    }

    /// The destination unique identifiers in the map.
    ///
    /// This is equivalent to accessing the `destination` property directly.
    public var values: [UniqueId] {
        destination
    }

    /// Returns all valid (source, destination) pairs in the map.
    ///
    /// Only pairs where both arrays have a value at the same index are included.
    public var pairs: [(UniqueId, UniqueId)] {
        let count = pairedCount
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            (source[index], destination[index])
        }
    }

    /// Converts the map to a dictionary.
    ///
    /// - Returns: A dictionary mapping source unique identifiers to destination
    ///   unique identifiers.
    ///
    /// - Note: If there are duplicate source identifiers, later values overwrite
    ///   earlier ones.
    public func toDictionary() -> [UniqueId: UniqueId] {
        var dict: [UniqueId: UniqueId] = [:]
        for (key, value) in pairs {
            dict[key] = value
        }
        return dict
    }

    /// Checks if the map contains a mapping for the specified source unique identifier.
    ///
    /// - Parameter key: The source unique identifier to check.
    ///
    /// - Returns: `true` if the source unique identifier exists in the map; otherwise, `false`.
    public func contains(_ key: UniqueId) -> Bool {
        source.contains(key)
    }

    /// Gets the destination unique identifier for a source unique identifier.
    ///
    /// - Parameter key: The source unique identifier to look up.
    ///
    /// - Returns: The corresponding destination unique identifier, or `nil` if the
    ///   source unique identifier is not in the map or has no corresponding destination.
    public func value(for key: UniqueId) -> UniqueId? {
        guard let index = source.firstIndex(of: key) else {
            return nil
        }
        guard index < destination.count else {
            return nil
        }
        return destination[index]
    }

    /// Returns a new map with an additional (source, destination) pair appended.
    ///
    /// - Parameters:
    ///   - key: The source unique identifier to add.
    ///   - value: The destination unique identifier to add.
    ///
    /// - Returns: A new `UniqueIdMap` containing all existing pairs plus the new pair.
    public func appending(source key: UniqueId, destination value: UniqueId) -> UniqueIdMap {
        var newSource = source
        var newDestination = destination
        newSource.append(key)
        newDestination.append(value)
        return UniqueIdMap(source: newSource, destination: newDestination)
    }

    /// Returns a new map with all pairs from another map appended.
    ///
    /// - Parameter other: The map whose pairs should be appended.
    ///
    /// - Returns: A new `UniqueIdMap` containing all pairs from both maps.
    public func appending(contentsOf other: UniqueIdMap) -> UniqueIdMap {
        var newSource = source
        var newDestination = destination
        newSource.append(contentsOf: other.source)
        newDestination.append(contentsOf: other.destination)
        return UniqueIdMap(source: newSource, destination: newDestination)
    }

    /// Gets the destination unique identifier for a source unique identifier.
    ///
    /// - Parameter key: The source unique identifier to look up.
    ///
    /// - Returns: The corresponding destination unique identifier.
    ///
    /// - Precondition: The source unique identifier must exist in the map
    ///   and have a corresponding destination.
    public subscript(key: UniqueId) -> UniqueId {
        guard let value = value(for: key) else {
            preconditionFailure("UniqueIdMap does not contain the specified key.")
        }
        return value
    }

    /// Returns an iterator over the (source, destination) pairs in the map.
    ///
    /// The iterator yields tuples of `(UniqueId, UniqueId)` for each valid pair
    /// in the map, in order.
    ///
    /// - Returns: An iterator that yields `(UniqueId, UniqueId)` tuples.
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
