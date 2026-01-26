//
// UniqueIdRange.swift
//
// Ported from MailKit (C#) to Swift.
//

/// An error that occurs when parsing a unique identifier range from a string.
public enum UniqueIdRangeParseError: Error, Sendable {
    /// The token could not be parsed as a valid unique identifier range.
    case invalidToken
}

/// A range of unique identifiers.
///
/// When dealing with a large range of messages, it is more efficient to use a
/// `UniqueIdRange` than a typical array of `UniqueId` values. The range stores
/// only the start and end values, but can iterate over all values in between.
///
/// Ranges can be either ascending (start <= end) or descending (start > end),
/// which affects the iteration order and sort order.
///
/// ## Example
///
/// ```swift
/// // Create a range from 1 to 100
/// let range = UniqueIdRange(start: UniqueId(id: 1), end: UniqueId(id: 100))
///
/// // Check if a UID is in the range
/// if range.contains(UniqueId(id: 50)) {
///     print("UID 50 is in the range")
/// }
///
/// // Iterate over all UIDs in the range
/// for uid in range {
///     print(uid)
/// }
/// ```
public struct UniqueIdRange: Sendable, Sequence, CustomStringConvertible {
    /// A range that encompasses all possible messages in a folder.
    ///
    /// Represents the range from `UniqueId.minValue` to `UniqueId.maxValue`,
    /// which includes all valid unique identifiers.
    public static let all = UniqueIdRange(validity: 0, start: UniqueId.minValue.id, end: UniqueId.maxValue.id)

    /// The UIDVALIDITY of the containing folder.
    ///
    /// The validity value is used to detect when the unique identifiers in a mailbox
    /// have been invalidated. A value of `0` indicates that the validity is not known.
    public let validity: UInt32

    private let start: UInt32
    private let end: UInt32

    /// Creates a new unique identifier range with the specified validity, start, and end values.
    ///
    /// - Parameters:
    ///   - validity: The UIDVALIDITY of the containing folder.
    ///   - start: The first unique identifier value in the range. Must be non-zero.
    ///   - end: The last unique identifier value in the range. Must be non-zero.
    ///
    /// - Precondition: Both `start` and `end` must be non-zero.
    public init(validity: UInt32, start: UInt32, end: UInt32) {
        precondition(start != 0, "UniqueIdRange start must be non-zero.")
        precondition(end != 0, "UniqueIdRange end must be non-zero.")
        self.validity = validity
        self.start = start
        self.end = end
    }

    /// Creates a new unique identifier range between two unique identifiers.
    ///
    /// The validity is taken from the `start` unique identifier.
    ///
    /// - Parameters:
    ///   - start: The first unique identifier in the range. Must be valid.
    ///   - end: The last unique identifier in the range. Must be valid.
    ///
    /// - Precondition: Both `start` and `end` must be valid unique identifiers.
    public init(start: UniqueId, end: UniqueId) {
        precondition(start.isValid, "UniqueIdRange start must be valid.")
        precondition(end.isValid, "UniqueIdRange end must be valid.")
        self.validity = start.validity
        self.start = start.id
        self.end = end.id
    }

    /// The sort order of the unique identifiers in the range.
    ///
    /// Returns `.ascending` if `start <= end`, otherwise `.descending`.
    public var sortOrder: SortOrder {
        start <= end ? .ascending : .descending
    }

    /// The minimum unique identifier in the range.
    ///
    /// Returns the smaller of the start and end values.
    public var min: UniqueId {
        if start < end {
            return UniqueId(validity: validity, id: start)
        }
        return UniqueId(validity: validity, id: end)
    }

    /// The maximum unique identifier in the range.
    ///
    /// Returns the larger of the start and end values.
    public var max: UniqueId {
        if start > end {
            return UniqueId(validity: validity, id: start)
        }
        return UniqueId(validity: validity, id: end)
    }

    /// The start of the unique identifier range.
    ///
    /// This is the first unique identifier that will be returned when iterating.
    public var startId: UniqueId {
        UniqueId(validity: validity, id: start)
    }

    /// The end of the unique identifier range.
    ///
    /// This is the last unique identifier that will be returned when iterating.
    public var endId: UniqueId {
        UniqueId(validity: validity, id: end)
    }

    /// The number of unique identifiers in the range.
    ///
    /// For very large ranges, this value is capped at `Int.max`.
    public var count: Int {
        let delta = start <= end ? end - start : start - end
        let length = UInt64(delta) + 1
        return length > UInt64(Int.max) ? Int.max : Int(length)
    }

    /// Checks if the range contains the specified unique identifier.
    ///
    /// - Parameter uid: The unique identifier to check.
    ///
    /// - Returns: `true` if the specified unique identifier is in the range; otherwise, `false`.
    public func contains(_ uid: UniqueId) -> Bool {
        if start <= end {
            return uid.id >= start && uid.id <= end
        }

        return uid.id <= start && uid.id >= end
    }

    /// Gets the index of the specified unique identifier within the range.
    ///
    /// - Parameter uid: The unique identifier to find.
    ///
    /// - Returns: The zero-based index of the unique identifier in the range,
    ///   or `nil` if the unique identifier is not in the range.
    public func index(of uid: UniqueId) -> Int? {
        if start <= end {
            guard uid.id >= start && uid.id <= end else {
                return nil
            }
            return Int(uid.id - start)
        }

        guard uid.id <= start && uid.id >= end else {
            return nil
        }
        return Int(start - uid.id)
    }

    /// Gets the unique identifier at the specified index.
    ///
    /// - Parameter index: The zero-based index of the unique identifier to retrieve.
    ///
    /// - Returns: The unique identifier at the specified index.
    ///
    /// - Precondition: `index` must be in the range `0..<count`.
    public subscript(index: Int) -> UniqueId {
        precondition(index >= 0 && index < count, "Index out of range.")
        let uid = start <= end ? start + UInt32(index) : start - UInt32(index)
        return UniqueId(validity: validity, id: uid)
    }

    /// Copies all of the unique identifiers in the range to the specified array.
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

    /// Returns an iterator over the unique identifiers in the range.
    ///
    /// The iterator yields unique identifiers in order from `startId` to `endId`,
    /// either ascending or descending depending on whether `start <= end`.
    ///
    /// - Returns: An iterator that yields `UniqueId` values.
    public func makeIterator() -> AnyIterator<UniqueId> {
        var current = start
        let isAscending = start <= end
        var done = false

        return AnyIterator {
            if done {
                return nil
            }

            let uid = UniqueId(validity: validity, id: current)

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

            return uid
        }
    }

    /// Returns a string representation of the unique identifier range.
    ///
    /// The format is `start:end`, or `start:*` if the end is `UInt32.max`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let range = UniqueIdRange(validity: 0, start: 1, end: 100)
    /// print(range) // "1:100"
    ///
    /// print(UniqueIdRange.all) // "1:*"
    /// ```
    public var description: String {
        if end == UInt32.max {
            return "\(start):*"
        }
        return "\(start):\(end)"
    }

    /// Parses a unique identifier range from a string.
    ///
    /// The expected format is `start:end` where `start` and `end` are non-zero
    /// positive integers, or `start:*` where `*` represents the maximum value.
    ///
    /// - Parameters:
    ///   - token: A string containing the unique identifier range to parse.
    ///   - validity: The UIDVALIDITY value to associate with the parsed range.
    ///
    /// - Throws: `UniqueIdRangeParseError.invalidToken` if the token cannot be parsed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let range = try UniqueIdRange(parsing: "1:100", validity: 12345)
    /// print(range.count) // 100
    ///
    /// let allRange = try UniqueIdRange(parsing: "1:*")
    /// print(allRange.endId.id) // 4294967295 (UInt32.max)
    /// ```
    public init(parsing token: String, validity: UInt32 = 0) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes = Array(trimmed.utf8)
        var index = 0

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

        skipWhitespace(bytes, &index)
        guard let parsedStart = UniqueId.parseNonZeroUInt32(bytes: bytes, index: &index) else {
            throw UniqueIdRangeParseError.invalidToken
        }

        skipWhitespace(bytes, &index)
        guard index < bytes.count, bytes[index] == 58 else {
            throw UniqueIdRangeParseError.invalidToken
        }
        index += 1
        skipWhitespace(bytes, &index)

        let parsedEnd: UInt32
        if index < bytes.count, bytes[index] == 42 {
            index += 1
            skipWhitespace(bytes, &index)
            guard index == bytes.count else {
                throw UniqueIdRangeParseError.invalidToken
            }
            parsedEnd = UInt32.max
        } else {
            guard let end = UniqueId.parseNonZeroUInt32(bytes: bytes, index: &index) else {
                throw UniqueIdRangeParseError.invalidToken
            }
            skipWhitespace(bytes, &index)
            guard index == bytes.count else {
                throw UniqueIdRangeParseError.invalidToken
            }
            parsedEnd = end
        }

        self.validity = validity
        self.start = parsedStart
        self.end = parsedEnd
    }
}
