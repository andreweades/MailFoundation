//
// ImapAclResponse.swift
//
// IMAP ACL response parsing.
//

import Foundation

public struct ImapAclEntry: Sendable, Equatable {
    public let identifier: String
    public let rights: String

    public init(identifier: String, rights: String) {
        self.identifier = identifier
        self.rights = rights
    }
}

public struct ImapAclResponse: Sendable, Equatable {
    public let mailbox: String
    public let entries: [ImapAclEntry]

    public static func parse(_ line: String) -> ImapAclResponse? {
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

        guard let command = readAtom(), command.uppercased() == "ACL" else { return nil }
        guard let mailboxValue = readStringOrNil(), let mailbox = mailboxValue else { return nil }

        var entries: [ImapAclEntry] = []
        while let identifierValue = readStringOrNil() {
            guard let identifier = identifierValue else { break }
            guard let rightsValue = readStringOrNil() else { return nil }
            let rights = rightsValue ?? ""
            entries.append(ImapAclEntry(identifier: identifier, rights: rights))
        }

        return ImapAclResponse(mailbox: mailbox, entries: entries)
    }
}

public struct ImapListRightsResponse: Sendable, Equatable {
    public let mailbox: String
    public let identifier: String
    public let requiredRights: String
    public let optionalRights: [String]

    public static func parse(_ line: String) -> ImapListRightsResponse? {
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

        guard let command = readAtom(), command.uppercased() == "LISTRIGHTS" else { return nil }
        guard let mailboxValue = readStringOrNil(), let mailbox = mailboxValue else { return nil }
        guard let identifierValue = readStringOrNil(), let identifier = identifierValue else { return nil }
        guard let requiredValue = readStringOrNil() else { return nil }
        let requiredRights = requiredValue ?? ""
        var optionalRights: [String] = []
        while let value = readStringOrNil() {
            if let right = value {
                optionalRights.append(right)
            }
        }
        return ImapListRightsResponse(
            mailbox: mailbox,
            identifier: identifier,
            requiredRights: requiredRights,
            optionalRights: optionalRights
        )
    }
}

public struct ImapMyRightsResponse: Sendable, Equatable {
    public let mailbox: String
    public let rights: String

    public static func parse(_ line: String) -> ImapMyRightsResponse? {
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

        guard let command = readAtom(), command.uppercased() == "MYRIGHTS" else { return nil }
        guard let mailboxValue = readStringOrNil(), let mailbox = mailboxValue else { return nil }
        guard let rightsValue = readStringOrNil() else { return nil }
        let rights = rightsValue ?? ""
        return ImapMyRightsResponse(mailbox: mailbox, rights: rights)
    }
}
