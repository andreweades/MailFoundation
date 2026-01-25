//
// ImapQuotaResponse.swift
//
// IMAP QUOTA/QUOTAROOT response parsing.
//

import Foundation

public struct ImapQuotaResource: Sendable, Equatable {
    public let name: String
    public let usage: Int
    public let limit: Int

    public init(name: String, usage: Int, limit: Int) {
        self.name = name
        self.usage = usage
        self.limit = limit
    }
}

public struct ImapQuotaResponse: Sendable, Equatable {
    public let root: String
    public let resources: [ImapQuotaResource]

    public static func parse(_ line: String) -> ImapQuotaResponse? {
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

        func readParenthesizedText() -> String? {
            skipWhitespace()
            guard index < trimmed.endIndex, trimmed[index] == "(" else { return nil }
            let start = index
            var depth = 0
            var inQuote = false
            var escape = false
            while index < trimmed.endIndex {
                let ch = trimmed[index]
                if inQuote {
                    if escape {
                        escape = false
                    } else if ch == "\\" {
                        escape = true
                    } else if ch == "\"" {
                        inQuote = false
                    }
                } else {
                    if ch == "\"" {
                        inQuote = true
                    } else if ch == "(" {
                        depth += 1
                    } else if ch == ")" {
                        depth -= 1
                        if depth == 0 {
                            let end = trimmed.index(after: index)
                            index = end
                            return String(trimmed[start..<end])
                        }
                    }
                }
                index = trimmed.index(after: index)
            }
            return nil
        }

        guard let command = readAtom(), command.uppercased() == "QUOTA" else { return nil }
        guard let rootValue = readStringOrNil(), let root = rootValue else { return nil }
        guard let listText = readParenthesizedText() else { return nil }
        var inner = listText.trimmingCharacters(in: .whitespacesAndNewlines)
        if inner.hasPrefix("("), inner.hasSuffix(")") {
            inner.removeFirst()
            inner.removeLast()
        }
        let tokens = tokenize(inner)
        var resources: [ImapQuotaResource] = []
        var idx = 0
        while idx + 2 < tokens.count {
            let name = tokens[idx]
            let usage = Int(tokens[idx + 1]) ?? 0
            let limit = Int(tokens[idx + 2]) ?? 0
            resources.append(ImapQuotaResource(name: name, usage: usage, limit: limit))
            idx += 3
        }
        return ImapQuotaResponse(root: root, resources: resources)
    }

    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            let ch = text[index]
            if ch.isWhitespace {
                index = text.index(after: index)
                continue
            }
            if ch == "\"" {
                index = text.index(after: index)
                var value = ""
                var escape = false
                while index < text.endIndex {
                    let current = text[index]
                    if escape {
                        value.append(current)
                        escape = false
                    } else if current == "\\" {
                        escape = true
                    } else if current == "\"" {
                        index = text.index(after: index)
                        break
                    } else {
                        value.append(current)
                    }
                    index = text.index(after: index)
                }
                tokens.append(value)
                continue
            }

            let start = index
            while index < text.endIndex {
                let current = text[index]
                if current.isWhitespace {
                    break
                }
                index = text.index(after: index)
            }
            tokens.append(String(text[start..<index]))
        }
        return tokens
    }
}

public struct ImapQuotaRootResponse: Sendable, Equatable {
    public let mailbox: String
    public let roots: [String]

    public static func parse(_ line: String) -> ImapQuotaRootResponse? {
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

        guard let command = readAtom(), command.uppercased() == "QUOTAROOT" else { return nil }
        guard let mailboxValue = readStringOrNil(), let mailbox = mailboxValue else { return nil }
        var roots: [String] = []
        while let rootValue = readStringOrNil() {
            if let root = rootValue {
                roots.append(root)
            }
        }
        return ImapQuotaRootResponse(mailbox: mailbox, roots: roots)
    }
}

public struct ImapQuotaRootResult: Sendable, Equatable {
    public let quotaRoot: ImapQuotaRootResponse?
    public let quotas: [ImapQuotaResponse]

    public init(quotaRoot: ImapQuotaRootResponse?, quotas: [ImapQuotaResponse]) {
        self.quotaRoot = quotaRoot
        self.quotas = quotas
    }
}
