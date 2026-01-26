//
// UniqueId.swift
//
// Ported from MailKit (C#) to Swift.
//

import Foundation

/// An error that occurs when parsing a unique identifier from a string.
public enum UniqueIdParseError: Error, Sendable {
    /// The token could not be parsed as a valid unique identifier.
    case invalidToken
}

/// A unique identifier for messages in an IMAP mailbox.
///
/// Represents a unique identifier for messages in a mail folder. A 32-bit value
/// assigned to each message, which when used with the unique identifier validity
/// value forms a 64-bit value that will never refer to any other message in the
/// mailbox or any subsequent mailbox with the same name.
///
/// Unique identifiers are assigned in a strictly ascending fashion in the mailbox;
/// as each message is added to the mailbox it is assigned a higher UID than the
/// message(s) which were added previously. Unlike message sequence numbers, unique
/// identifiers are not necessarily contiguous.
///
/// The unique identifier of a message will not change during the session, and should
/// not change between sessions. Any change of unique identifiers between sessions
/// can be detected using the UIDVALIDITY mechanism. Persistent unique identifiers
/// are required for a client to resynchronize its state from a previous session
/// with the server (e.g., disconnected or offline access clients).
///
/// For more information about unique identifiers, see
/// [RFC 3501, section 2.3.1.1](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3.1.1).
///
/// ## Example
///
/// ```swift
/// // Create a unique identifier with a specific validity and id
/// let uid = UniqueId(validity: 12345, id: 42)
///
/// // Create a unique identifier without validity
/// let simpleUid = UniqueId(id: 100)
///
/// // Parse a unique identifier from a string
/// let parsed = try UniqueId(parsing: "42", validity: 12345)
/// ```
public struct UniqueId: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// The invalid unique identifier value.
    ///
    /// This value represents an invalid unique identifier where the `id` is `0`.
    public static let invalid = UniqueId(validity: 0, id: 0, allowInvalid: true)

    /// The minimum valid unique identifier value.
    ///
    /// This is the smallest possible valid unique identifier, with an `id` of `1`.
    public static let minValue = UniqueId(validity: 0, id: 1, allowInvalid: true)

    /// The maximum unique identifier value.
    ///
    /// This is the largest possible unique identifier, with an `id` of `UInt32.max`.
    public static let maxValue = UniqueId(validity: 0, id: UInt32.max, allowInvalid: true)

    /// The UIDVALIDITY of the containing folder.
    ///
    /// The validity value is used to detect when the unique identifiers in a mailbox
    /// have been invalidated. When the UIDVALIDITY changes, all previously stored
    /// unique identifiers for that mailbox are no longer valid.
    ///
    /// A value of `0` indicates that the validity is not known.
    public let validity: UInt32

    /// The unique identifier value.
    ///
    /// The identifier is a 32-bit value assigned to each message in the mailbox.
    /// A value of `0` indicates an invalid unique identifier.
    public let id: UInt32

    /// Indicates whether the unique identifier is valid.
    ///
    /// A unique identifier is valid if its `id` is non-zero.
    ///
    /// - Returns: `true` if the unique identifier is valid; otherwise, `false`.
    public var isValid: Bool {
        id != 0
    }

    /// Creates a new unique identifier with the specified validity and id.
    ///
    /// - Parameters:
    ///   - validity: The UIDVALIDITY of the containing folder.
    ///   - id: The unique identifier value. Must be non-zero.
    ///
    /// - Precondition: `id` must be non-zero.
    public init(validity: UInt32, id: UInt32) {
        precondition(id != 0, "UniqueId id must be non-zero.")
        self.validity = validity
        self.id = id
    }

    /// Creates a new unique identifier with the specified id and no validity.
    ///
    /// - Parameter id: The unique identifier value. Must be non-zero.
    ///
    /// - Precondition: `id` must be non-zero.
    public init(id: UInt32) {
        self.init(validity: 0, id: id)
    }

    private init(validity: UInt32, id: UInt32, allowInvalid: Bool) {
        self.validity = validity
        self.id = id
    }

    /// Compares two unique identifiers.
    ///
    /// Compares the `id` values of two unique identifiers. Validity values
    /// are not used in the comparison.
    ///
    /// - Parameters:
    ///   - lhs: The first unique identifier to compare.
    ///   - rhs: The second unique identifier to compare.
    ///
    /// - Returns: `true` if `lhs` is less than `rhs`; otherwise, `false`.
    public static func < (lhs: UniqueId, rhs: UniqueId) -> Bool {
        lhs.id < rhs.id
    }

    /// Returns a string representation of the unique identifier.
    ///
    /// The string representation contains only the `id` value as a decimal number.
    public var description: String {
        String(id)
    }

    /// Parses a unique identifier from a string.
    ///
    /// - Parameters:
    ///   - token: A string containing the unique identifier to parse.
    ///   - validity: The UIDVALIDITY value to associate with the parsed identifier.
    ///
    /// - Throws: `UniqueIdParseError.invalidToken` if the token cannot be parsed
    ///   as a valid unique identifier (must be a non-zero positive integer).
    ///
    /// ## Example
    ///
    /// ```swift
    /// let uid = try UniqueId(parsing: "42", validity: 12345)
    /// print(uid.id)       // 42
    /// print(uid.validity) // 12345
    /// ```
    public init(parsing token: String, validity: UInt32 = 0) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes = Array(trimmed.utf8)
        var index = 0
        guard let parsed = Self.parseNonZeroUInt32(bytes: bytes, index: &index), index == bytes.count else {
            throw UniqueIdParseError.invalidToken
        }

        self.validity = validity
        self.id = parsed
    }

    /// Parses a non-zero unsigned 32-bit integer from a byte array.
    ///
    /// - Parameters:
    ///   - bytes: The byte array to parse from.
    ///   - index: The starting index in the byte array. Updated to point past the parsed number.
    ///
    /// - Returns: The parsed value, or `nil` if parsing fails or the value is zero.
    internal static func parseNonZeroUInt32(bytes: [UInt8], index: inout Int) -> UInt32? {
        var value: UInt32 = 0
        var hasDigits = false
        let maxDiv10 = UInt32.max / 10
        let maxMod10 = UInt32.max % 10

        while index < bytes.count {
            let byte = bytes[index]
            if byte < 48 || byte > 57 {
                break
            }

            let digit = UInt32(byte - 48)
            hasDigits = true

            if value > maxDiv10 || (value == maxDiv10 && digit > maxMod10) {
                return nil
            }

            value = (value * 10) + digit
            index += 1
        }

        guard hasDigits, value != 0 else {
            return nil
        }

        return value
    }
}
