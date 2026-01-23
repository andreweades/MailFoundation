//
// ImapMailboxListResponse.swift
//
// IMAP LIST/LSUB response parsing.
//

import Foundation

public enum ImapMailboxListKind: Sendable {
    case list
    case lsub
}

public struct ImapMailboxListResponse: Sendable, Equatable {
    public let kind: ImapMailboxListKind
    public let attributes: [String]
    public let delimiter: String?
    public let name: String
    public let decodedName: String

    public init(kind: ImapMailboxListKind, attributes: [String], delimiter: String?, name: String) {
        self.kind = kind
        self.attributes = attributes
        self.delimiter = delimiter
        self.name = name
        self.decodedName = ImapMailboxEncoding.decode(name)
    }

    public static func parse(_ line: String) -> ImapMailboxListResponse? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("*") else { return nil }
        var index = trimmed.index(after: trimmed.startIndex)

        func skipWhitespace() {
            while index < trimmed.endIndex, trimmed[index].isWhitespace {
                index = trimmed.index(after: index)
            }
        }

        func readAtom() -> String? {
            skipWhitespace()
            guard index < trimmed.endIndex else { return nil }
            let start = index
            while index < trimmed.endIndex {
                let ch = trimmed[index]
                if ch.isWhitespace || ch == "(" || ch == ")" {
                    break
                }
                index = trimmed.index(after: index)
            }
            guard start < index else { return nil }
            return String(trimmed[start..<index])
        }

        func readQuoted() -> String? {
            guard index < trimmed.endIndex, trimmed[index] == "\"" else { return nil }
            index = trimmed.index(after: index)
            var result = ""
            var escape = false
            while index < trimmed.endIndex {
                let ch = trimmed[index]
                if escape {
                    result.append(ch)
                    escape = false
                } else if ch == "\\" {
                    escape = true
                } else if ch == "\"" {
                    index = trimmed.index(after: index)
                    return result
                } else {
                    result.append(ch)
                }
                index = trimmed.index(after: index)
            }
            return nil
        }

        func readStringOrNil() -> String?? {
            skipWhitespace()
            guard index < trimmed.endIndex else { return nil }
            if trimmed[index] == "\"" {
                if let value = readQuoted() {
                    return .some(value)
                }
                return nil
            }
            guard let atom = readAtom() else { return nil }
            if atom.uppercased() == "NIL" {
                return .some(nil)
            }
            return .some(atom)
        }

        func readAttributes() -> [String]? {
            skipWhitespace()
            guard index < trimmed.endIndex, trimmed[index] == "(" else { return nil }
            index = trimmed.index(after: index)
            var result: [String] = []
            while index < trimmed.endIndex {
                skipWhitespace()
                if index < trimmed.endIndex, trimmed[index] == ")" {
                    index = trimmed.index(after: index)
                    return result
                }
                if let value = readAtom() {
                    result.append(value)
                    continue
                }
                if let quoted = readQuoted() {
                    result.append(quoted)
                    continue
                }
                return nil
            }
            return nil
        }

        guard let command = readAtom() else { return nil }
        let upper = command.uppercased()
        let kind: ImapMailboxListKind
        if upper == "LIST" {
            kind = .list
        } else if upper == "LSUB" {
            kind = .lsub
        } else {
            return nil
        }

        guard let attributes = readAttributes() else { return nil }
        guard let delimiterValue = readStringOrNil() else { return nil }
        guard let mailboxValue = readStringOrNil() else { return nil }
        guard let name = mailboxValue else { return nil }

        return ImapMailboxListResponse(kind: kind, attributes: attributes, delimiter: delimiterValue, name: name)
    }
}
