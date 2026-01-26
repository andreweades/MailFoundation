//
// ImapAnnotation.swift
//
// IMAP ANNOTATEMORE helpers.
//

import Foundation

public struct ImapAnnotationAttribute: Sendable, Equatable {
    public let name: String
    public let value: String?

    public init(name: String, value: String?) {
        self.name = name
        self.value = value
    }
}

public struct ImapAnnotationEntry: Sendable, Equatable {
    public let entry: String
    public let attributes: [ImapAnnotationAttribute]

    public init(entry: String, attributes: [ImapAnnotationAttribute]) {
        self.entry = entry
        self.attributes = attributes
    }
}

public struct ImapAnnotationResponse: Sendable, Equatable {
    public let mailbox: String
    public let entry: ImapAnnotationEntry

    public static func parse(_ message: ImapLiteralMessage) -> ImapAnnotationResponse? {
        let trimmed = message.line.trimmingCharacters(in: .whitespacesAndNewlines)
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

        guard let command = readAtom(), command.uppercased() == "ANNOTATION" else { return nil }
        guard let mailboxValue = readStringOrNil(), let mailbox = mailboxValue else { return nil }
        guard let entryValue = readStringOrNil(), let entry = entryValue else { return nil }

        guard let listStart = trimmed.firstIndex(of: "(") else {
            return ImapAnnotationResponse(mailbox: mailbox, entry: ImapAnnotationEntry(entry: entry, attributes: []))
        }
        var inner = String(trimmed[listStart...])
        if inner.first == "(" {
            inner.removeFirst()
        }
        if inner.last == ")" {
            inner.removeLast()
        }
        var tokens = tokenize(inner)
        if let literal = message.literal,
           let last = tokens.last,
           last.first == "{" {
            tokens[tokens.count - 1] = String(decoding: literal, as: UTF8.self)
        }

        var attributes: [ImapAnnotationAttribute] = []
        var idx = 0
        while idx + 1 < tokens.count {
            let name = tokens[idx]
            let rawValue = tokens[idx + 1]
            let value = rawValue.caseInsensitiveCompare("NIL") == .orderedSame ? nil : rawValue
            attributes.append(ImapAnnotationAttribute(name: name, value: value))
            idx += 2
        }
        return ImapAnnotationResponse(mailbox: mailbox, entry: ImapAnnotationEntry(entry: entry, attributes: attributes))
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

public struct ImapAnnotationResult: Sendable, Equatable {
    public let mailbox: String
    public let entries: [ImapAnnotationEntry]

    public init(mailbox: String, entries: [ImapAnnotationEntry]) {
        self.mailbox = mailbox
        self.entries = entries
    }
}

enum ImapAnnotation {
    static func formatEntryList(_ entries: [String]) -> String {
        let rendered = entries.map { ImapMetadata.atomOrQuoted($0) }.joined(separator: " ")
        return "(\(rendered))"
    }

    static func formatAttributeList(_ attributes: [String]) -> String {
        let rendered = attributes.map { ImapMetadata.atomOrQuoted($0) }.joined(separator: " ")
        return "(\(rendered))"
    }

    static func formatAttributes(_ attributes: [ImapAnnotationAttribute]) -> String {
        let rendered = attributes.map { attribute in
            let name = ImapMetadata.atomOrQuoted(attribute.name)
            if let value = attribute.value {
                return "\(name) \(ImapMetadata.quote(value))"
            }
            return "\(name) NIL"
        }
        .joined(separator: " ")
        return "(\(rendered))"
    }
}
