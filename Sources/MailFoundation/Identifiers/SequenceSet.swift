//
// SequenceSet.swift
//
// IMAP message sequence set helper.
//

import Foundation

/// An error that occurs when parsing a sequence set from a string.
public enum SequenceSetParseError: Error, Sendable {
    /// The token could not be parsed as a valid sequence set.
    case invalidToken
}

/// A set of IMAP message sequence numbers.
///
/// Message sequence numbers are 1-based indices that refer to messages in a mailbox
/// in their current order. Unlike unique identifiers (`UniqueId`), sequence numbers
/// can change when messages are expunged from the mailbox.
///
/// A `SequenceSet` efficiently represents sets of sequence numbers by storing
/// contiguous ranges rather than individual values. This is particularly useful
/// for IMAP commands that operate on multiple messages.
///
/// The `*` character in IMAP represents the highest sequence number in the mailbox,
/// which is represented by `UInt32.max` in this implementation.
///
/// ## Example
///
/// ```swift
/// // Create a sequence set from an array of sequence numbers
/// let set = SequenceSet([1, 2, 3, 5, 6, 7, 10])
/// print(set) // "1:3,5:7,10"
///
/// // Parse a sequence set from a string
/// let parsed = try SequenceSet(parsing: "1:5,10,15:*")
///
/// // Check if a sequence number is in the set
/// if set.contains(5) {
///     print("Contains sequence number 5")
/// }
/// ```
public struct SequenceSet: Sendable, Sequence, CustomStringConvertible {
    private struct Range: Sendable {
        var start: UInt32
        var end: UInt32

        var count: Int {
            let delta = start <= end ? end - start : start - end
            let length = UInt64(delta) + 1
            return length > UInt64(Int.max) ? Int.max : Int(length)
        }

        func contains(_ value: UInt32) -> Bool {
            if start <= end {
                return value >= start && value <= end
            }
            return value <= start && value >= end
        }

        subscript(index: Int) -> UInt32 {
            if start <= end {
                return start + UInt32(index)
            }
            return start - UInt32(index)
        }

        func serialized() -> String {
            if start == end {
                return SequenceSet.formatSequence(start)
            }

            if start <= end && end == UInt32.max {
                return "\(start):*"
            }

            let startText = SequenceSet.formatSequence(start)
            let endText = SequenceSet.formatSequence(end)
            return "\(startText):\(endText)"
        }
    }

    private var ranges: [Range] = []
    private var totalCount: Int64 = 0

    /// The sort order of the sequence numbers in the set.
    ///
    /// The sort order is automatically determined based on the input values.
    /// When the sequence numbers are in ascending or descending order, this
    /// property reflects that order. Otherwise, it is `.none`.
    public private(set) var sortOrder: SortOrder

    /// Creates an empty sequence set with the specified sort order.
    ///
    /// - Parameter sortOrder: The sorting order for the sequence numbers.
    public init(sortOrder: SortOrder = .none) {
        self.sortOrder = sortOrder
    }

    /// Creates a sequence set from an array of sequence numbers.
    ///
    /// Contiguous sequence numbers are automatically combined into ranges for
    /// efficient storage and serialization.
    ///
    /// - Parameters:
    ///   - sequences: An array of sequence numbers. All values must be non-zero.
    ///   - sortOrder: The sorting order for the sequence numbers.
    ///     If `.none` (the default), the sort order is automatically determined.
    ///
    /// - Precondition: All values in `sequences` must be non-zero.
    public init(_ sequences: [UInt32], sortOrder: SortOrder = .none) {
        self.sortOrder = sortOrder
        guard !sequences.isEmpty else { return }
        let result = SequenceSet.buildRanges(from: sequences)
        self.ranges = result.ranges
        self.totalCount = result.totalCount
        if sortOrder == .none {
            self.sortOrder = result.sortOrder
        }
    }

    /// Creates a sequence set from an array of integer sequence numbers.
    ///
    /// Contiguous sequence numbers are automatically combined into ranges for
    /// efficient storage and serialization.
    ///
    /// - Parameters:
    ///   - sequences: An array of sequence numbers as `Int` values.
    ///     All values must be non-zero and within the `UInt32` range.
    ///   - sortOrder: The sorting order for the sequence numbers.
    ///     If `.none` (the default), the sort order is automatically determined.
    ///
    /// - Precondition: All values in `sequences` must be non-zero.
    public init(_ sequences: [Int], sortOrder: SortOrder = .none) {
        let mapped = sequences.map { UInt32($0) }
        self.init(mapped, sortOrder: sortOrder)
    }

    /// The number of sequence numbers in the set.
    ///
    /// For very large sets, this value is capped at `Int.max`.
    public var count: Int {
        totalCount > Int64(Int.max) ? Int.max : Int(totalCount)
    }

    /// Indicates whether the set contains no sequence numbers.
    public var isEmpty: Bool {
        totalCount == 0
    }

    /// Checks if the set contains the specified sequence number.
    ///
    /// - Parameter value: The sequence number to check.
    ///
    /// - Returns: `true` if the set contains the specified sequence number; otherwise, `false`.
    public func contains(_ value: UInt32) -> Bool {
        for range in ranges where range.contains(value) {
            return true
        }
        return false
    }

    /// Returns an iterator over the sequence numbers in the set.
    ///
    /// The iterator yields sequence numbers in the order determined by the
    /// ranges stored in the set.
    ///
    /// - Returns: An iterator that yields `UInt32` sequence numbers.
    public func makeIterator() -> AnyIterator<UInt32> {
        var rangeIndex = 0
        var elementIndex = 0

        return AnyIterator {
            guard rangeIndex < ranges.count else {
                return nil
            }

            let range = ranges[rangeIndex]
            let value = range[elementIndex]
            elementIndex += 1

            if elementIndex >= range.count {
                rangeIndex += 1
                elementIndex = 0
            }

            return value
        }
    }

    /// Returns a string representation of the sequence set.
    ///
    /// The format is a comma-separated list of sequence numbers and ranges
    /// (e.g., "1:3,5,10:15"). The `*` character represents the highest
    /// sequence number in the mailbox.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let set = SequenceSet([1, 2, 3, 10, 11, 12])
    /// print(set) // "1:3,10:12"
    /// ```
    public var description: String {
        ranges.map { $0.serialized() }.joined(separator: ",")
    }

    /// Parses a sequence set from a string.
    ///
    /// The expected format is a comma-separated list of sequence numbers and ranges,
    /// such as "1,3:5,10,15:*". The `*` character represents the highest sequence
    /// number in the mailbox.
    ///
    /// - Parameter token: A string containing the sequence set to parse.
    ///
    /// - Throws: `SequenceSetParseError.invalidToken` if the token cannot be parsed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let set = try SequenceSet(parsing: "1:5,10,15:20")
    /// print(set.count) // 12 (1,2,3,4,5,10,15,16,17,18,19,20)
    /// ```
    public init(parsing token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SequenceSetParseError.invalidToken
        }

        let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { throw SequenceSetParseError.invalidToken }

        var set = SequenceSet()
        var order: SortOrder = .none
        var sorted = true
        var prev: UInt32 = 0

        for part in parts {
            let segment = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !segment.isEmpty else { throw SequenceSetParseError.invalidToken }
            let pieces = segment.split(separator: ":", omittingEmptySubsequences: false)
            if pieces.count == 1 {
                guard let value = Self.parseToken(String(pieces[0])) else { throw SequenceSetParseError.invalidToken }
                set.ranges.append(Range(start: value, end: value))
                set.totalCount += 1

                if sorted && set.ranges.count > 1 {
                    switch order {
                    case .none:
                        order = value >= prev ? .ascending : .descending
                    case .descending:
                        sorted = value <= prev
                    case .ascending:
                        sorted = value >= prev
                    }
                }
                prev = value
            } else if pieces.count == 2 {
                guard let start = Self.parseToken(String(pieces[0])) else { throw SequenceSetParseError.invalidToken }
                guard let end = Self.parseToken(String(pieces[1])) else { throw SequenceSetParseError.invalidToken }

                let range = Range(start: start, end: end)
                set.totalCount += Int64(range.count)
                set.ranges.append(range)

                if sorted {
                    switch order {
                    case .none:
                        order = start <= end ? .ascending : .descending
                    case .descending:
                        sorted = start >= end && start <= prev
                    case .ascending:
                        sorted = start <= end && start >= prev
                    }
                }
                prev = end
            } else {
                throw SequenceSetParseError.invalidToken
            }
        }

        set.sortOrder = sorted ? order : .none
        self = set
    }

    private static func parseToken(_ value: String) -> UInt32? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "*" {
            return UInt32.max
        }
        guard let number = UInt32(trimmed), number != 0 else {
            return nil
        }
        return number
    }

    private static func formatSequence(_ value: UInt32) -> String {
        value == UInt32.max ? "*" : String(value)
    }

    private static func buildRanges(from sequences: [UInt32]) -> (ranges: [Range], totalCount: Int64, sortOrder: SortOrder) {
        var ranges: [Range] = []
        var totalCount: Int64 = 0
        var sortOrder: SortOrder = .none
        var sorted = true

        var start = sequences[0]
        precondition(start != 0, "SequenceSet values must be non-zero.")
        var prev = start
        var direction: Int = 0

        for index in 1..<sequences.count {
            let value = sequences[index]
            precondition(value != 0, "SequenceSet values must be non-zero.")

            if sorted {
                if sortOrder == .none {
                    sortOrder = value >= prev ? .ascending : .descending
                } else if sortOrder == .ascending, value < prev {
                    sorted = false
                } else if sortOrder == .descending, value > prev {
                    sorted = false
                }
            }

            if direction == 0 {
                if value == prev + 1 {
                    direction = 1
                    prev = value
                    continue
                } else if prev > 1, value == prev - 1 {
                    direction = -1
                    prev = value
                    continue
                }
            } else if direction == 1, value == prev + 1 {
                prev = value
                continue
            } else if direction == -1, value == prev - 1 {
                prev = value
                continue
            }

            let range = Range(start: start, end: prev)
            ranges.append(range)
            totalCount += Int64(range.count)
            start = value
            prev = value
            direction = 0
        }

        let range = Range(start: start, end: prev)
        ranges.append(range)
        totalCount += Int64(range.count)

        if !sorted {
            sortOrder = .none
        }
        return (ranges, totalCount, sortOrder)
    }
}
