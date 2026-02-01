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
// ImapStatusResponse.swift
//
// IMAP STATUS response parsing helpers.
//

public struct ImapStatusResponse: Sendable, Equatable {
    public let mailbox: String
    public let items: [String: Int]

    public static func parse(_ line: String) -> ImapStatusResponse? {
        parse(line, literals: [])
    }

    /// Parses a STATUS response from a literal-aware message.
    ///
    /// - Parameter message: The literal response message.
    /// - Returns: The parsed status response, or `nil` if parsing fails.
    public static func parse(_ message: ImapLiteralMessage) -> ImapStatusResponse? {
        parse(message.line, literals: message.literals)
    }

    private static func parse(_ line: String, literals: [[UInt8]]) -> ImapStatusResponse? {
        var reader = ImapLineTokenReader(line: line, literals: literals)
        guard let token = reader.readToken(), token.type == .asterisk else { return nil }
        guard reader.readCaseInsensitiveAtom("STATUS") else { return nil }
        guard let mailboxToken = reader.readToken() else { return nil }
        guard let mailbox = readStringValue(token: mailboxToken, reader: &reader, allowNil: false) else { return nil }
        guard let items = readStatusItems(reader: &reader) else { return nil }
        return ImapStatusResponse(mailbox: mailbox, items: items)
    }

    private static func readStatusItems(reader: inout ImapLineTokenReader) -> [String: Int]? {
        guard let token = reader.readToken(), token.type == .openParen else { return nil }
        var items: [String: Int] = [:]
        while let next = reader.peekToken() {
            if next.type == .closeParen {
                _ = reader.readToken()
                break
            }
            guard let keyToken = reader.readToken(),
                  let key = readStringValue(token: keyToken, reader: &reader, allowNil: false) else {
                return nil
            }
            let value = reader.readNumber() ?? 0
            items[key.uppercased()] = value
        }
        return items
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
