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

    /// Parses an ANNOTATION response from a literal-aware message.
    ///
    /// - Parameter message: The literal response message.
    /// - Returns: The parsed annotation response, or `nil` if parsing fails.
    public static func parse(_ message: ImapLiteralMessage) -> ImapAnnotationResponse? {
        var reader = ImapLineTokenReader(line: message.line, literals: message.literals)
        guard let token = reader.readToken(), token.type == .asterisk else { return nil }
        guard reader.readCaseInsensitiveAtom("ANNOTATION") else { return nil }
        guard let mailboxToken = reader.readToken() else { return nil }
        guard let mailbox = readStringValue(token: mailboxToken, reader: &reader, allowNil: false) else { return nil }
        guard let entryToken = reader.readToken() else { return nil }
        guard let entry = readStringValue(token: entryToken, reader: &reader, allowNil: false) else { return nil }

        var attributes: [ImapAnnotationAttribute] = []
        if let peek = reader.peekToken(), peek.type == .openParen {
            _ = reader.readToken()
            while let next = reader.peekToken() {
                if next.type == .closeParen {
                    _ = reader.readToken()
                    break
                }
                guard let nameToken = reader.readToken(),
                      let name = readStringValue(token: nameToken, reader: &reader, allowNil: false) else {
                    return nil
                }
                guard let valueToken = reader.readToken() else { return nil }
                let value = readStringValue(token: valueToken, reader: &reader, allowNil: true)
                attributes.append(ImapAnnotationAttribute(name: name, value: value))
            }
        }

        return ImapAnnotationResponse(mailbox: mailbox, entry: ImapAnnotationEntry(entry: entry, attributes: attributes))
    }

    private static func readStringValue(
        token: ImapToken,
        reader: inout ImapLineTokenReader,
        allowNil: Bool
    ) -> String? {
        switch token.type {
        case .atom, .qString, .flag:
            return token.stringValue
        case .literal:
            return reader.literalString(for: token)
        case .nilValue:
            return allowNil ? nil : nil
        default:
            return nil
        }
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
