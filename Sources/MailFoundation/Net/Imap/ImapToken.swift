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
// ImapToken.swift
//
// Lightweight IMAP token model used by the stream decoder.
//

import Foundation

enum ImapTokenType: Sendable, Equatable {
    case noData
    case error
    case nilValue
    case atom
    case flag
    case qString
    case literal
    case eoln
    case openParen
    case closeParen
    case asterisk
    case openBracket
    case closeBracket
}

struct ImapToken: Sendable, Equatable {
    let type: ImapTokenType
    let stringValue: String?
    let numberValue: Int?
    let literalIndex: Int?

    static let eoln = ImapToken(type: .eoln, stringValue: nil, numberValue: nil, literalIndex: nil)

    init(type: ImapTokenType, stringValue: String? = nil, numberValue: Int? = nil, literalIndex: Int? = nil) {
        self.type = type
        self.stringValue = stringValue
        self.numberValue = numberValue
        self.literalIndex = literalIndex
    }

    var literalLength: Int? {
        guard type == .literal else { return nil }
        return numberValue
    }
}

struct ImapTokenScan: Sendable, Equatable {
    let token: ImapToken
    let consumed: [UInt8]
}
