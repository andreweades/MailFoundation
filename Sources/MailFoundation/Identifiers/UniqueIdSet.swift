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
// UniqueIdSet.swift
//
// Ported from MailKit (C#) to Swift.
//

/// An error that occurs when working with a unique identifier set.
public enum UniqueIdSetParseError: Error, Sendable {
    /// The token could not be parsed as a valid unique identifier set.
    case invalidToken

    /// The maximum length parameter is invalid (negative).
    case invalidMaxLength
}

/// A set of unique identifiers.
///
/// When dealing with a large number of unique identifiers, it may be more efficient
/// to use a `UniqueIdSet` than a typical array of `UniqueId` values. The set internally
/// stores contiguous ranges of identifiers, which can significantly reduce memory usage
/// and improve serialization efficiency.
///
/// The set supports different sort orders:
/// - `.ascending`: UIDs are maintained in ascending order, enabling efficient binary search.
/// - `.descending`: UIDs are maintained in descending order, enabling efficient binary search.
/// - `.none`: UIDs are stored in insertion order without sorting.
///
/// ## Example
///
/// ```swift
/// // Create a new set with ascending sort order
/// var set = UniqueIdSet(sortOrder: .ascending)
///
/// // Add unique identifiers
/// set.add(UniqueId(id: 5))
/// set.add(UniqueId(id: 3))
/// set.add(UniqueId(id: 4))
///
/// // The set efficiently stores contiguous ranges
/// print(set) // "3:5"
///
/// // Check membership
/// if set.contains(UniqueId(id: 4)) {
///     print("Contains UID 4")
/// }
/// ```
public struct UniqueIdSet: Sendable, Sequence, CustomStringConvertible {
    private struct Range: Sendable {
        var start: UInt32
        var end: UInt32

        var count: Int {
            let delta = start <= end ? end - start : start - end
            let length = UInt64(delta) + 1
            return length > UInt64(Int.max) ? Int.max : Int(length)
        }

        func contains(_ uid: UInt32) -> Bool {
            if start <= end {
                return uid >= start && uid <= end
            }
            return uid <= start && uid >= end
        }

        func index(of uid: UInt32) -> Int? {
            if start <= end {
                guard uid >= start && uid <= end else {
                    return nil
                }
                return Int(uid - start)
            }

            guard uid <= start && uid >= end else {
                return nil
            }
            return Int(start - uid)
        }

        subscript(index: Int) -> UInt32 {
            if start <= end {
                return start + UInt32(index)
            }
            return start - UInt32(index)
        }

        func makeIterator() -> AnyIterator<UInt32> {
            var current = start
            let isAscending = start <= end
            var done = false

            return AnyIterator {
                if done {
                    return nil
                }

                let value = current

                if isAscending {
                    if current == end {
                        done = true
                    } else {
                        current += 1
                    }
                } else {
                    if current == end {
                        done = true
                    } else {
                        current -= 1
                    }
                }

                return value
            }
        }

        func serialized() -> String {
            if start == UInt32.max && end == UInt32.max {
                return "*"
            }
            if start == end {
                return UniqueIdSet.formatUid(start)
            }

            if start <= end && end == UInt32.max {
                return "\(start):*"
            }

            let startText = UniqueIdSet.formatUid(start)
            let endText = UniqueIdSet.formatUid(end)
            return "\(startText):\(endText)"
        }
    }

    private var ranges: [Range] = []
    private var totalCount: Int64 = 0

    /// The sort order of the unique identifiers in the set.
    ///
    /// When the sort order is `.ascending` or `.descending`, binary search is used
    /// for efficient lookups and insertions. When the sort order is `.none`, linear
    /// search is used.
    public private(set) var sortOrder: SortOrder

    /// The UIDVALIDITY of the containing folder.
    ///
    /// The validity value is used to detect when the unique identifiers in a mailbox
    /// have been invalidated. A value of `0` indicates that the validity is not known.
    public private(set) var validity: UInt32

    /// Creates a new unique identifier set with the specified validity and sort order.
    ///
    /// - Parameters:
    ///   - validity: The UIDVALIDITY of the containing folder.
    ///   - sortOrder: The sorting order to use for the unique identifiers.
    public init(validity: UInt32, sortOrder: SortOrder = .none) {
        self.validity = validity
        self.sortOrder = sortOrder
    }

    /// Creates a new unique identifier set with the specified sort order.
    ///
    /// - Parameter sortOrder: The sorting order to use for the unique identifiers.
    public init(sortOrder: SortOrder = .none) {
        self.init(validity: 0, sortOrder: sortOrder)
    }

    /// Creates a new unique identifier set containing the specified unique identifiers.
    ///
    /// - Parameters:
    ///   - uids: An array of unique identifiers to add to the set.
    ///   - sortOrder: The sorting order to use for the unique identifiers.
    public init(_ uids: [UniqueId], sortOrder: SortOrder = .none) {
        self.init(sortOrder: sortOrder)
        for uid in uids {
            add(uid)
        }
    }

    /// The number of unique identifiers in the set.
    ///
    /// For very large sets, this value is capped at `Int.max`.
    public var count: Int {
        totalCount > Int64(Int.max) ? Int.max : Int(totalCount)
    }

    /// Indicates whether the set contains no unique identifiers.
    public var isEmpty: Bool {
        totalCount == 0
    }

    private func indexOfRange(for uid: UInt32) -> Int? {
        guard !ranges.isEmpty else {
            return nil
        }

        if sortOrder != .none {
            return binarySearch(uid)
        }

        for index in ranges.indices {
            if ranges[index].contains(uid) {
                return index
            }
        }

        return nil
    }

    private func binarySearch(_ uid: UInt32) -> Int? {
        var minIndex = 0
        var maxIndex = ranges.count

        while minIndex < maxIndex {
            let i = minIndex + ((maxIndex - minIndex) / 2)
            let range = ranges[i]

            if sortOrder == .ascending {
                if uid >= range.start {
                    if uid <= range.end {
                        return i
                    }
                    minIndex = i + 1
                } else {
                    maxIndex = i
                }
            } else {
                if uid >= range.end {
                    if uid <= range.start {
                        return i
                    }
                    maxIndex = i
                } else {
                    minIndex = i + 1
                }
            }
        }

        return nil
    }

    private mutating func binaryInsertAscending(_ uid: UInt32) {
        var minIndex = 0
        var maxIndex = ranges.count
        var insertIndex = 0

        while minIndex < maxIndex {
            insertIndex = minIndex + ((maxIndex - minIndex) / 2)
            let range = ranges[insertIndex]

            if uid >= range.start {
                if uid <= range.end {
                    return
                }

                if uid == range.end + 1 {
                    if insertIndex + 1 < ranges.count, uid + 1 >= ranges[insertIndex + 1].start {
                        ranges[insertIndex] = Range(start: range.start, end: ranges[insertIndex + 1].end)
                        ranges.remove(at: insertIndex + 1)
                        totalCount += 1
                        return
                    }

                    ranges[insertIndex] = Range(start: range.start, end: uid)
                    totalCount += 1
                    return
                }

                minIndex = insertIndex + 1
                insertIndex = minIndex
            } else {
                if uid == range.start - 1 {
                    if insertIndex > 0, uid - 1 <= ranges[insertIndex - 1].end {
                        ranges[insertIndex - 1] = Range(start: ranges[insertIndex - 1].start, end: range.end)
                        ranges.remove(at: insertIndex)
                        totalCount += 1
                        return
                    }

                    ranges[insertIndex] = Range(start: uid, end: range.end)
                    totalCount += 1
                    return
                }

                maxIndex = insertIndex
            }
        }

        let range = Range(start: uid, end: uid)
        if insertIndex < ranges.count {
            ranges.insert(range, at: insertIndex)
        } else {
            ranges.append(range)
        }
        totalCount += 1
    }

    private mutating func binaryInsertDescending(_ uid: UInt32) {
        var minIndex = 0
        var maxIndex = ranges.count
        var insertIndex = 0

        while minIndex < maxIndex {
            insertIndex = minIndex + ((maxIndex - minIndex) / 2)
            let range = ranges[insertIndex]

            if uid <= range.start {
                if uid >= range.end {
                    return
                }

                if uid == range.end - 1 {
                    if insertIndex + 1 < ranges.count, uid - 1 <= ranges[insertIndex + 1].start {
                        ranges[insertIndex] = Range(start: range.start, end: ranges[insertIndex + 1].end)
                        ranges.remove(at: insertIndex + 1)
                        totalCount += 1
                        return
                    }

                    ranges[insertIndex] = Range(start: range.start, end: uid)
                    totalCount += 1
                    return
                }

                minIndex = insertIndex + 1
                insertIndex = minIndex
            } else {
                if uid == range.start + 1 {
                    if insertIndex > 0, uid + 1 >= ranges[insertIndex - 1].end {
                        ranges[insertIndex - 1] = Range(start: ranges[insertIndex - 1].start, end: range.end)
                        ranges.remove(at: insertIndex)
                        totalCount += 1
                        return
                    }

                    ranges[insertIndex] = Range(start: uid, end: range.end)
                    totalCount += 1
                    return
                }

                maxIndex = insertIndex
            }
        }

        let range = Range(start: uid, end: uid)
        if insertIndex < ranges.count {
            ranges.insert(range, at: insertIndex)
        } else {
            ranges.append(range)
        }
        totalCount += 1
    }

    private mutating func append(_ uid: UInt32) {
        if indexOfRange(for: uid) != nil {
            return
        }

        totalCount += 1

        if let lastIndex = ranges.indices.last {
            let range = ranges[lastIndex]

            if range.start == range.end {
                if uid == range.end + 1 || uid == range.end - 1 {
                    ranges[lastIndex] = Range(start: range.start, end: uid)
                    return
                }
            } else if range.start < range.end {
                if uid == range.end + 1 {
                    ranges[lastIndex] = Range(start: range.start, end: uid)
                    return
                }
            } else if range.start > range.end {
                if uid == range.end - 1 {
                    ranges[lastIndex] = Range(start: range.start, end: uid)
                    return
                }
            }
        }

        ranges.append(Range(start: uid, end: uid))
    }

    /// Adds a unique identifier to the set.
    ///
    /// If the set has a sort order of `.ascending` or `.descending`, the identifier
    /// is inserted in the appropriate position using binary insertion. If the sort
    /// order is `.none`, the identifier is appended to the end.
    ///
    /// Adjacent identifiers are automatically merged into ranges for efficient storage.
    ///
    /// - Parameter uid: The unique identifier to add.
    ///
    /// - Precondition: `uid` must be valid (non-zero id).
    public mutating func add(_ uid: UniqueId) {
        precondition(uid.isValid, "Invalid unique identifier.")

        if ranges.isEmpty {
            ranges.append(Range(start: uid.id, end: uid.id))
            totalCount += 1
            return
        }

        switch sortOrder {
        case .descending:
            binaryInsertDescending(uid.id)
        case .ascending:
            binaryInsertAscending(uid.id)
        case .none:
            append(uid.id)
        }
    }

    /// Adds multiple unique identifiers to the set.
    ///
    /// - Parameter uids: An array of unique identifiers to add.
    public mutating func add(contentsOf uids: [UniqueId]) {
        for uid in uids {
            add(uid)
        }
    }

    /// Removes all unique identifiers from the set.
    ///
    /// After calling this method, `count` will be `0` and `isEmpty` will be `true`.
    public mutating func clear() {
        ranges.removeAll(keepingCapacity: true)
        totalCount = 0
    }

    /// Checks if the set contains the specified unique identifier.
    ///
    /// - Parameter uid: The unique identifier to check.
    ///
    /// - Returns: `true` if the set contains the specified unique identifier; otherwise, `false`.
    public func contains(_ uid: UniqueId) -> Bool {
        indexOfRange(for: uid.id) != nil
    }

    /// Gets the index of the specified unique identifier within the set.
    ///
    /// - Parameter uid: The unique identifier to find.
    ///
    /// - Returns: The zero-based index of the unique identifier in the set,
    ///   or `nil` if the unique identifier is not in the set.
    public func index(of uid: UniqueId) -> Int? {
        var offset = 0
        for range in ranges {
            if range.contains(uid.id), let rangeIndex = range.index(of: uid.id) {
                return offset + rangeIndex
            }
            offset += range.count
        }
        return nil
    }

    /// Gets the unique identifier at the specified index.
    ///
    /// - Parameter index: The zero-based index of the unique identifier to retrieve.
    ///
    /// - Returns: The unique identifier at the specified index.
    ///
    /// - Precondition: `index` must be in the range `0..<count`.
    public func uniqueId(at index: Int) -> UniqueId {
        precondition(index >= 0 && Int64(index) < totalCount, "Index out of range.")

        var offset = 0
        for range in ranges {
            if index >= offset + range.count {
                offset += range.count
                continue
            }

            let uid = range[index - offset]
            return UniqueId(validity: validity, id: uid)
        }

        preconditionFailure("Index out of range.")
    }

    /// Removes the unique identifier at the specified index.
    ///
    /// - Parameter index: The zero-based index of the unique identifier to remove.
    ///
    /// - Precondition: `index` must be in the range `0..<count`.
    public mutating func remove(at index: Int) {
        precondition(index >= 0 && Int64(index) < totalCount, "Index out of range.")

        var offset = 0
        for rangeIndex in ranges.indices {
            let range = ranges[rangeIndex]
            if index >= offset + range.count {
                offset += range.count
                continue
            }

            let uid = range[index - offset]
            remove(rangeIndex: rangeIndex, uid: uid)
            return
        }
    }

    /// Removes the specified unique identifier from the set.
    ///
    /// - Parameter uid: The unique identifier to remove.
    ///
    /// - Returns: `true` if the unique identifier was removed; otherwise, `false`.
    @discardableResult
    public mutating func remove(_ uid: UniqueId) -> Bool {
        guard let rangeIndex = indexOfRange(for: uid.id) else {
            return false
        }

        remove(rangeIndex: rangeIndex, uid: uid.id)
        return true
    }

    private mutating func remove(rangeIndex: Int, uid: UInt32) {
        let range = ranges[rangeIndex]

        if uid == range.start {
            if range.start != range.end {
                if range.start <= range.end {
                    ranges[rangeIndex] = Range(start: uid + 1, end: range.end)
                } else {
                    ranges[rangeIndex] = Range(start: uid - 1, end: range.end)
                }
            } else {
                ranges.remove(at: rangeIndex)
            }
        } else if uid == range.end {
            if range.start <= range.end {
                ranges[rangeIndex] = Range(start: range.start, end: uid - 1)
            } else {
                ranges[rangeIndex] = Range(start: range.start, end: uid + 1)
            }
        } else {
            if range.start < range.end {
                ranges.insert(Range(start: range.start, end: uid - 1), at: rangeIndex)
                ranges[rangeIndex + 1] = Range(start: uid + 1, end: range.end)
            } else {
                ranges.insert(Range(start: range.start, end: uid + 1), at: rangeIndex)
                ranges[rangeIndex + 1] = Range(start: uid - 1, end: range.end)
            }
        }

        totalCount -= 1
    }

    /// Copies all of the unique identifiers in the set to the specified array.
    ///
    /// - Parameters:
    ///   - array: The array to copy the unique identifiers to.
    ///   - index: The index in the array at which to start copying.
    ///
    /// - Precondition: `index` must be non-negative and within the array bounds.
    /// - Precondition: The array must have enough space to hold all copied elements.
    public func copy(to array: inout [UniqueId], startingAt index: Int) {
        precondition(index >= 0, "Index out of range.")
        precondition(index <= array.count, "Index out of range.")
        precondition(array.count - index >= count, "Destination array is too small.")

        var currentIndex = index
        for uid in self {
            array[currentIndex] = uid
            currentIndex += 1
        }
    }

    /// Returns an iterator over the unique identifiers in the set.
    ///
    /// The iterator yields unique identifiers in the order determined by the set's
    /// sort order and the order in which ranges were added.
    ///
    /// - Returns: An iterator that yields `UniqueId` values.
    public func makeIterator() -> AnyIterator<UniqueId> {
        var rangeIndex = 0
        var rangeIterator: AnyIterator<UInt32>? = ranges.first?.makeIterator()

        return AnyIterator {
            while true {
                if let iterator = rangeIterator, let value = iterator.next() {
                    return UniqueId(validity: validity, id: value)
                }

                rangeIndex += 1
                guard rangeIndex < ranges.count else {
                    return nil
                }
                rangeIterator = ranges[rangeIndex].makeIterator()
            }
        }
    }

    /// Formats the set as multiple strings that fit within the specified character length.
    ///
    /// This is useful for IMAP commands that have a maximum command length. The set
    /// is serialized as comma-separated ranges (e.g., "1:5,10,15:20") and split into
    /// multiple strings if needed.
    ///
    /// - Parameter maxLength: The maximum length of any returned string.
    ///
    /// - Returns: An array of strings representing the set, each within the maximum length.
    ///
    /// - Throws: `UniqueIdSetParseError.invalidMaxLength` if `maxLength` is negative.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var set = UniqueIdSet(sortOrder: .ascending)
    /// set.add(UniqueId(id: 1))
    /// set.add(UniqueId(id: 2))
    /// set.add(UniqueId(id: 3))
    /// set.add(UniqueId(id: 10))
    ///
    /// let subsets = try set.serializedSubsets(maxLength: 10)
    /// // Returns ["1:3,10"] or split into multiple strings if longer
    /// ```
    public func serializedSubsets(maxLength: Int) throws -> [String] {
        guard maxLength >= 0 else {
            throw UniqueIdSetParseError.invalidMaxLength
        }

        var subsets: [String] = []
        var current = ""

        for range in ranges {
            let serializedRange = range.serialized()
            if !current.isEmpty {
                if current.count + 1 + serializedRange.count > maxLength {
                    subsets.append(current)
                    current = ""
                } else {
                    current.append(",")
                }
            }
            current.append(serializedRange)
        }

        subsets.append(current)
        return subsets
    }

    /// Returns a string representation of the unique identifier set.
    ///
    /// The format is a comma-separated list of UIDs and ranges (e.g., "1:3,5,10:15").
    /// The `*` character represents `UInt32.max`.
    public var description: String {
        (try? serializedSubsets(maxLength: Int.max).first) ?? ""
    }

    /// Formats an array of unique identifiers as a string.
    ///
    /// Contiguous identifiers are automatically combined into ranges for efficient
    /// representation.
    ///
    /// - Parameter uids: The unique identifiers to format.
    ///
    /// - Returns: A string representation of the unique identifiers.
    ///
    /// - Throws: `UniqueIdSetParseError.invalidMaxLength` if an internal error occurs.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let uids = [UniqueId(id: 1), UniqueId(id: 2), UniqueId(id: 3), UniqueId(id: 10)]
    /// let str = try UniqueIdSet.toString(uids)
    /// print(str) // "1:3,10"
    /// ```
    public static func toString(_ uids: [UniqueId]) throws -> String {
        return try serializedSubsets(for: uids, maxLength: Int.max).first ?? ""
    }

    /// Formats a unique identifier range as multiple strings.
    ///
    /// - Parameters:
    ///   - range: The unique identifier range to format.
    ///   - maxLength: The maximum length of any returned string.
    ///
    /// - Returns: An array containing the string representation of the range.
    ///
    /// - Throws: `UniqueIdSetParseError.invalidMaxLength` if `maxLength` is negative.
    public static func serializedSubsets(for range: UniqueIdRange, maxLength: Int) throws -> [String] {
        guard maxLength >= 0 else {
            throw UniqueIdSetParseError.invalidMaxLength
        }
        return [range.description]
    }

    /// Formats a unique identifier set as multiple strings.
    ///
    /// - Parameters:
    ///   - set: The unique identifier set to format.
    ///   - maxLength: The maximum length of any returned string.
    ///
    /// - Returns: An array of strings representing the set.
    ///
    /// - Throws: `UniqueIdSetParseError.invalidMaxLength` if `maxLength` is negative.
    public static func serializedSubsets(for set: UniqueIdSet, maxLength: Int) throws -> [String] {
        return try set.serializedSubsets(maxLength: maxLength)
    }

    /// Formats an array of unique identifiers as multiple strings.
    ///
    /// Contiguous identifiers are automatically combined into ranges for efficient
    /// representation. The output is split into multiple strings if needed to stay
    /// within the maximum length.
    ///
    /// - Parameters:
    ///   - uids: The unique identifiers to format.
    ///   - maxLength: The maximum length of any returned string.
    ///
    /// - Returns: An array of strings representing the unique identifiers.
    ///
    /// - Throws: `UniqueIdSetParseError.invalidMaxLength` if `maxLength` is negative.
    ///
    /// - Precondition: All unique identifiers in `uids` must be valid.
    public static func serializedSubsets(for uids: [UniqueId], maxLength: Int) throws -> [String] {
        guard maxLength >= 0 else {
            throw UniqueIdSetParseError.invalidMaxLength
        }

        if uids.isEmpty {
            return [""]
        }

        var subsets: [String] = []
        var current = ""
        var index = 0

        while index < uids.count {
            let uid = uids[index]
            precondition(uid.isValid, "One or more of the uids is invalid.")

            let start = uid.id
            var end = uid.id
            var i = index + 1

            if i < uids.count {
                if uids[i].id == end + 1 {
                    end = uids[i].id
                    i += 1
                    while i < uids.count && uids[i].id == end + 1 {
                        end += 1
                        i += 1
                    }
                } else if uids[i].id == end - 1 {
                    end = uids[i].id
                    i += 1
                    while i < uids.count && uids[i].id == end - 1 {
                        end -= 1
                        i += 1
                    }
                }
            }

            let next: String
            if start != end {
                let startText = formatUid(start)
                let endText = formatUid(end)
                next = "\(startText):\(endText)"
            } else {
                next = formatUid(start)
            }

            if !current.isEmpty {
                if current.count + 1 + next.count > maxLength {
                    subsets.append(current)
                    current = ""
                } else {
                    current.append(",")
                }
            }

            current.append(next)
            index = i
        }

        subsets.append(current)
        return subsets
    }

    private static func formatUid(_ value: UInt32) -> String {
        value == UInt32.max ? "*" : String(value)
    }

    /// Attempts to parse a unique identifier set from a string.
    ///
    /// - Parameters:
    ///   - token: The string to parse.
    ///   - validity: The UIDVALIDITY value to associate with parsed identifiers.
    ///   - minValue: On return, contains the minimum unique identifier in the set, or `nil`.
    ///   - maxValue: On return, contains the maximum unique identifier in the set, or `nil`.
    ///
    /// - Returns: The parsed `UniqueIdSet`, or `nil` if parsing fails.
    internal static func tryParse(_ token: String, validity: UInt32, minValue: inout UniqueId?, maxValue: inout UniqueId?) -> UniqueIdSet? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes = Array(trimmed.utf8)
        var index = 0

        guard !bytes.isEmpty else {
            return nil
        }

        func skipWhitespace(_ bytes: [UInt8], _ index: inout Int) {
            while index < bytes.count {
                let byte = bytes[index]
                if byte == 32 || byte == 9 {
                    index += 1
                } else {
                    break
                }
            }
        }

        var set = UniqueIdSet(validity: validity)
        var order: SortOrder = .none
        var sorted = true
        var min = UInt32.max
        var max: UInt32 = 0
        var prev: UInt32 = 0

        while true {
            skipWhitespace(bytes, &index)
            guard let start = parseUidOrStar(bytes: bytes, index: &index) else {
                return nil
            }

            min = Swift.min(min, start)
            max = Swift.max(max, start)

            skipWhitespace(bytes, &index)
            if index < bytes.count, bytes[index] == 58 {
                index += 1
                skipWhitespace(bytes, &index)
                guard let end = parseUidOrStar(bytes: bytes, index: &index) else {
                    return nil
                }

                min = Swift.min(min, end)
                max = Swift.max(max, end)

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
                set.ranges.append(Range(start: start, end: start))
                set.totalCount += 1

                if sorted && set.ranges.count > 1 {
                    switch order {
                    case .none:
                        order = start >= prev ? .ascending : .descending
                    case .descending:
                        sorted = start <= prev
                    case .ascending:
                        sorted = start >= prev
                    }
                }

                prev = start
            }

            skipWhitespace(bytes, &index)
            if index >= bytes.count {
                break
            }

            guard bytes[index] == 44 else {
                return nil
            }
            index += 1
        }

        set.sortOrder = sorted ? order : .none

        if min <= max {
            minValue = UniqueId(validity: validity, id: min)
            maxValue = UniqueId(validity: validity, id: max)
        }

        return set
    }

    /// Parses a unique identifier set from a string.
    ///
    /// The expected format is a comma-separated list of UIDs and ranges, such as
    /// "1,3:5,10,15:20". The `*` character can be used to represent `UInt32.max`.
    ///
    /// - Parameters:
    ///   - token: A string containing the unique identifier set to parse.
    ///   - validity: The UIDVALIDITY value to associate with the parsed identifiers.
    ///
    /// - Throws: `UniqueIdSetParseError.invalidToken` if the token cannot be parsed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let set = try UniqueIdSet(parsing: "1:3,5,10:15", validity: 12345)
    /// print(set.count) // 10 (1,2,3,5,10,11,12,13,14,15)
    /// ```
    public init(parsing token: String, validity: UInt32 = 0) throws {
        var minValue: UniqueId?
        var maxValue: UniqueId?
        guard let set = Self.tryParse(token, validity: validity, minValue: &minValue, maxValue: &maxValue) else {
            throw UniqueIdSetParseError.invalidToken
        }
        self = set
    }

    private static func parseUidOrStar(bytes: [UInt8], index: inout Int) -> UInt32? {
        guard index < bytes.count else { return nil }
        if bytes[index] == 42 { // '*'
            index += 1
            return UInt32.max
        }
        return UniqueId.parseNonZeroUInt32(bytes: bytes, index: &index)
    }
}
