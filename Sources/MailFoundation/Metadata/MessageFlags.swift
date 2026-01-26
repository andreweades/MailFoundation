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
// MessageFlags.swift
//
// Ported from MailKit (C#) to Swift.
//

/// An option set of message flags.
///
/// Message flags represent the state of a message in an IMAP mailbox. These are the
/// standard system flags defined by the IMAP protocol (RFC 3501), plus an indicator
/// for user-defined flags (keywords).
///
/// ## Topics
///
/// ### Standard Flags
/// - ``seen``
/// - ``answered``
/// - ``flagged``
/// - ``deleted``
/// - ``draft``
/// - ``recent``
///
/// ### User-Defined Flags
/// - ``userDefined``
///
/// ## Example
///
/// ```swift
/// var flags: MessageFlags = [.seen, .flagged]
///
/// if flags.contains(.seen) {
///     print("Message has been read")
/// }
///
/// flags.insert(.answered)
/// flags.remove(.flagged)
/// ```
public struct MessageFlags: OptionSet, Sendable {
    /// The raw value of the option set.
    public let rawValue: UInt32

    /// Creates a message flags option set from a raw value.
    ///
    /// - Parameter rawValue: The raw value representing the flags.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// No message flags are set.
    public static let none = MessageFlags([])

    /// The message has been read.
    ///
    /// Corresponds to the `\Seen` system flag in IMAP.
    public static let seen = MessageFlags(rawValue: 1 << 0)

    /// The message has been answered (replied to).
    ///
    /// Corresponds to the `\Answered` system flag in IMAP.
    public static let answered = MessageFlags(rawValue: 1 << 1)

    /// The message has been flagged for importance.
    ///
    /// Corresponds to the `\Flagged` system flag in IMAP. This is often displayed
    /// as a star or flag icon in email clients.
    public static let flagged = MessageFlags(rawValue: 1 << 2)

    /// The message has been marked for deletion.
    ///
    /// Corresponds to the `\Deleted` system flag in IMAP. Messages with this flag
    /// are typically removed when the mailbox is expunged.
    public static let deleted = MessageFlags(rawValue: 1 << 3)

    /// The message is marked as a draft.
    ///
    /// Corresponds to the `\Draft` system flag in IMAP, indicating that the message
    /// is not complete and is still being composed.
    public static let draft = MessageFlags(rawValue: 1 << 4)

    /// The message has just recently arrived in the folder.
    ///
    /// Corresponds to the `\Recent` system flag in IMAP. This flag is session-specific
    /// and indicates that this is the first session notified about this message.
    ///
    /// - Note: This flag is read-only and cannot be modified by clients.
    public static let recent = MessageFlags(rawValue: 1 << 5)

    /// User-defined flags (keywords) are present.
    ///
    /// This flag indicates that the message has one or more user-defined keywords
    /// in addition to or instead of the standard system flags.
    public static let userDefined = MessageFlags(rawValue: 1 << 6)

    /// Parses an array of flag strings into a flags option set and keywords array.
    ///
    /// This method converts IMAP flag strings (e.g., `"\Seen"`, `"\Flagged"`) into
    /// the corresponding ``MessageFlags`` values. Any unrecognized flags are treated
    /// as user-defined keywords and returned separately.
    ///
    /// - Parameter rawFlags: An array of flag strings to parse.
    /// - Returns: A tuple containing the parsed flags and any user-defined keywords.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let (flags, keywords) = MessageFlags.parse(["\\Seen", "\\Flagged", "custom-label"])
    /// // flags == [.seen, .flagged, .userDefined]
    /// // keywords == ["custom-label"]
    /// ```
    public static func parse(_ rawFlags: [String]) -> (flags: MessageFlags, keywords: [String]) {
        var flags: MessageFlags = []
        var keywords: [String] = []

        for raw in rawFlags {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let normalized = trimmed.hasPrefix("\\") ? String(trimmed.dropFirst()) : trimmed

            switch normalized.uppercased() {
            case "SEEN":
                flags.insert(.seen)
            case "ANSWERED":
                flags.insert(.answered)
            case "FLAGGED":
                flags.insert(.flagged)
            case "DELETED":
                flags.insert(.deleted)
            case "DRAFT":
                flags.insert(.draft)
            case "RECENT":
                flags.insert(.recent)
            default:
                keywords.append(trimmed)
                flags.insert(.userDefined)
            }
        }

        return (flags, keywords)
    }
}
