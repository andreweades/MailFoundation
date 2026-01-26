//
// ThreadableSubject.swift
//
// Ported from MailKit MessageThreader.GetThreadableSubject.
//

import Foundation

/// Utilities for parsing and normalizing message subjects for threading.
///
/// `ThreadableSubject` provides functionality to extract a normalized subject from
/// a message subject line by removing common prefixes like "Re:", "Re[#]:", "Fwd:",
/// and mailing list tags like "[listname]". This normalized subject can then be
/// used to group messages into conversation threads.
///
/// ## Topics
///
/// ### Parsing
/// - ``parse(_:)-2v0ww``
/// - ``parse(_:)-81d1y``
///
/// ### Result
/// - ``Result``
///
/// ## Example
///
/// ```swift
/// let result = ThreadableSubject.parse("Re: [swift-users] Question about protocols")
/// print(result.normalized)  // "Question about protocols"
/// print(result.replyDepth)  // 1
///
/// let result2 = ThreadableSubject.parse("Re[3]: Hello")
/// print(result2.replyDepth)  // 3
/// ```
public enum ThreadableSubject {
    /// The result of parsing a message subject for threading.
    public struct Result: Sendable, Equatable {
        /// The normalized subject with prefixes removed.
        ///
        /// All "Re:", "Re[#]:", "Fwd:", and mailing list tags have been stripped.
        /// Whitespace is normalized to single spaces.
        public let normalized: String

        /// The reply depth based on the prefixes found.
        ///
        /// Each "Re:", "Fwd:", or "Re[n]:" prefix increments this counter.
        /// For "Re[n]:" prefixes, the value of n is added.
        public let replyDepth: Int
    }

    /// Parses an optional subject string for threading.
    ///
    /// - Parameter subject: The subject string to parse, or `nil`.
    /// - Returns: A result with the normalized subject and reply depth.
    ///   If `subject` is `nil`, returns an empty normalized subject with depth 0.
    public static func parse(_ subject: String?) -> Result {
        guard let subject else {
            return Result(normalized: "", replyDepth: 0)
        }
        return parse(subject)
    }

    /// Parses a subject string for threading.
    ///
    /// This method removes common prefixes from the subject to create a normalized
    /// version suitable for threading. The following are removed:
    /// - "Re:" prefixes (case-insensitive)
    /// - "Re[n]:" prefixes with numeric counts
    /// - "Fwd:" prefixes (case-insensitive)
    /// - Mailing list tags in square brackets like "[list-name]"
    ///
    /// The method also normalizes whitespace and removes the "(no subject)" placeholder.
    ///
    /// - Parameter subject: The subject string to parse.
    /// - Returns: A result with the normalized subject and reply depth.
    public static func parse(_ subject: String) -> Result {
        var replyDepth = 0
        let chars = Array(subject)
        var startIndex = 0
        var endIndex = chars.count

        while true {
            skipWhiteSpace(chars, index: &startIndex)
            var index = startIndex
            let left = endIndex - index

            if left < 3 {
                break
            }

            if left >= 4, isForward(chars, index: index) {
                startIndex = index + 4
                replyDepth += 1
                continue
            }

            if isReply(chars, index: index) {
                if index + 2 < endIndex, chars[index + 2] == ":" {
                    startIndex = index + 3
                    replyDepth += 1
                    continue
                }

                if index + 2 < endIndex, chars[index + 2] == "[" || chars[index + 2] == "(" {
                    let close: Character = chars[index + 2] == "[" ? "]" : ")"
                    index += 3
                    var count = 0
                    if skipDigits(chars, index: &index, count: &count),
                       endIndex - index >= 2,
                       chars[index] == close,
                       chars[index + 1] == ":" {
                        startIndex = index + 2
                        replyDepth += count
                        continue
                    }
                }
            } else if chars[index] == "[", index + 1 < endIndex, isLetterOrDigit(chars[index + 1]) {
                index += 2
                skipMailingListName(chars, index: &index)
                if endIndex - index >= 1, chars[index] == "]" {
                    startIndex = index + 1
                    continue
                }
            }

            break
        }

        while endIndex > 0, isWhitespace(chars[endIndex - 1]) {
            endIndex -= 1
        }

        var builder = ""
        var lwsp = false
        if startIndex < endIndex {
            for i in startIndex..<endIndex {
                if isWhitespace(chars[i]) {
                    if !lwsp {
                        builder.append(" ")
                        lwsp = true
                    }
                } else {
                    builder.append(chars[i])
                    lwsp = false
                }
            }
        }

        if builder.compare("(no subject)", options: .caseInsensitive) == .orderedSame {
            builder = ""
        }

        return Result(normalized: builder, replyDepth: replyDepth)
    }

    private static func isForward(_ subject: [Character], index: Int) -> Bool {
        guard index + 3 < subject.count else { return false }
        return equalsIgnoreCase(subject[index], ascii: "f")
            && equalsIgnoreCase(subject[index + 1], ascii: "w")
            && equalsIgnoreCase(subject[index + 2], ascii: "d")
            && subject[index + 3] == ":"
    }

    private static func isReply(_ subject: [Character], index: Int) -> Bool {
        guard index + 1 < subject.count else { return false }
        return equalsIgnoreCase(subject[index], ascii: "r")
            && equalsIgnoreCase(subject[index + 1], ascii: "e")
    }

    private static func equalsIgnoreCase(_ lhs: Character, ascii: Character) -> Bool {
        String(lhs).lowercased() == String(ascii)
    }

    private static func skipWhiteSpace(_ subject: [Character], index: inout Int) {
        while index < subject.count, isWhitespace(subject[index]) {
            index += 1
        }
    }

    private static func isMailingListName(_ ch: Character) -> Bool {
        ch == "-" || ch == "_" || isLetterOrDigit(ch)
    }

    private static func skipMailingListName(_ subject: [Character], index: inout Int) {
        while index < subject.count, isMailingListName(subject[index]) {
            index += 1
        }
    }

    private static func skipDigits(_ subject: [Character], index: inout Int, count: inout Int) -> Bool {
        let startIndex = index
        count = 0

        while index < subject.count, isDigit(subject[index]) {
            count = (count * 10) + digitValue(subject[index])
            index += 1
        }

        return index > startIndex
    }

    private static func digitValue(_ ch: Character) -> Int {
        guard let scalar = ch.unicodeScalars.first else { return 0 }
        let value = scalar.value
        guard value >= 48, value <= 57 else { return 0 }
        return Int(value - 48)
    }

    private static func isWhitespace(_ ch: Character) -> Bool {
        ch.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }

    private static func isLetterOrDigit(_ ch: Character) -> Bool {
        ch.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }

    private static func isDigit(_ ch: Character) -> Bool {
        ch.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }
}
