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
// ImapIdResponse.swift
//
// IMAP ID response parsing.
//

import Foundation

public struct ImapIdResponse: Sendable, Equatable {
    public let values: [String: String?]

    public static func parse(_ line: String) -> ImapIdResponse? {
        var reader = ImapLineTokenReader(line: line)
        guard let token = reader.readToken(), token.type == .asterisk else { return nil }
        guard reader.readCaseInsensitiveAtom("ID") else { return nil }
        guard let next = reader.readToken() else { return nil }
        if next.type == .nilValue {
            return ImapIdResponse(values: [:])
        }
        guard next.type == .openParen else { return nil }

        var values: [String: String?] = [:]
        while let peek = reader.peekToken() {
            if peek.type == .closeParen {
                _ = reader.readToken()
                break
            }
            guard let keyToken = reader.readToken(),
                  let key = readStringValue(token: keyToken, reader: &reader, allowNil: false) else {
                return nil
            }
            guard let valueToken = reader.readToken() else { return nil }
            let value = readStringValue(token: valueToken, reader: &reader, allowNil: true)
            values[key] = value
        }

        return ImapIdResponse(values: values)
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
