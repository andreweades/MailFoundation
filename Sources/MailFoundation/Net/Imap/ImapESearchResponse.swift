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
// ImapESearchResponse.swift
//
// IMAP ESEARCH response parsing helpers.
//

public struct ImapESearchResponse: Sendable, Equatable {
    public let ids: [UInt32]
    public let count: Int?
    public let min: UInt32?
    public let max: UInt32?
    public let isUid: Bool

    public static func parse(_ line: String) -> ImapESearchResponse? {
        var reader = ImapLineTokenReader(line: line)
        guard let token = reader.readToken(), token.type == .asterisk else { return nil }
        guard reader.readCaseInsensitiveAtom("ESEARCH") else { return nil }

        if let peek = reader.peekToken(), peek.type == .openParen {
            reader.skipValue()
        }

        var isUid = false
        if let peek = reader.peekToken(),
           peek.type == .atom,
           let value = peek.stringValue,
           value.caseInsensitiveEquals("UID") {
            _ = reader.readToken()
            isUid = true
        }

        var ids: [UInt32] = []
        var count: Int?
        var minValue: UInt32?
        var maxValue: UInt32?

        while let keyToken = reader.readToken() {
            guard keyToken.type == .atom, let key = keyToken.stringValue else { break }
            let upper = key.uppercased()
            let valueToken = reader.readToken()

            switch upper {
            case "ALL":
                if let valueToken,
                   let value = readStringValue(token: valueToken, reader: &reader, allowNil: true),
                   let set = try? SequenceSet(parsing: value) {
                    ids = Array(set)
                }
            case "COUNT":
                if let parsed = readIntValue(token: valueToken, reader: &reader) {
                    count = parsed
                }
            case "MIN":
                if let parsed = readIntValue(token: valueToken, reader: &reader) {
                    minValue = UInt32(parsed)
                }
            case "MAX":
                if let parsed = readIntValue(token: valueToken, reader: &reader) {
                    maxValue = UInt32(parsed)
                }
            default:
                continue
            }
        }

        return ImapESearchResponse(ids: ids, count: count, min: minValue, max: maxValue, isUid: isUid)
    }
}

private extension String {
    func caseInsensitiveEquals(_ other: String) -> Bool {
        compare(other, options: [.caseInsensitive]) == .orderedSame
    }
}

private func readStringValue(
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

private func readIntValue(token: ImapToken?, reader: inout ImapLineTokenReader) -> Int? {
    guard let token else { return nil }
    switch token.type {
    case .atom, .qString, .flag:
        if let value = token.stringValue {
            return Int(value)
        }
        return nil
    case .literal:
        if let value = reader.literalString(for: token) {
            return Int(value)
        }
        return nil
    case .nilValue:
        return nil
    default:
        return nil
    }
}
