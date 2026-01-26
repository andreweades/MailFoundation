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

import Testing
@testable import MailFoundation

@Test("MessageIdList parses space-delimited IDs")
func messageIdListParsesSpaceDelimited() {
    let value = "id1@example.com id2@example.com"
    let list = MessageIdList.parse(value)
    #expect(list?.ids == ["id1@example.com", "id2@example.com"])
}

@Test("MessageIdList ignores comments")
func messageIdListIgnoresComments() {
    let value = "(foo) id1@example.com (bar)"
    let list = MessageIdList.parse(value)
    #expect(list?.ids == ["id1@example.com"])
}

@Test("MessageIdList parses comma-delimited IDs")
func messageIdListParsesCommaDelimited() {
    let value = "id1@example.com, id2@example.com"
    let list = MessageIdList.parse(value)
    #expect(list?.ids == ["id1@example.com", "id2@example.com"])
}

@Test("MessageIdList matches MimeKit good references")
func messageIdListGoodReferences() {
    let cases: [(raw: String, expected: String)] = [
        ("<local-part@domain1@domain2>", "local-part@domain1@domain2"),
        ("<local-part@>", "local-part@"),
        ("<local-part>", "local-part"),
        ("<:invalid-local-part;@domain.com>", ":invalid-local-part;@domain.com")
    ]

    for (raw, expected) in cases {
        let list = MessageIdList.parse(raw)
        #expect(list?.ids.first == expected)
        #expect(MessageIdList.parseMessageId(raw) == expected)
    }
}

@Test("MessageIdList rejects broken references")
func messageIdListBrokenReferences() {
    let cases = [
        " (this is an unterminated comment...",
        "(this is just a comment)",
        "<",
        "<local-part",
        "<local-part;",
        "<local-part@ (unterminated comment...",
        "<local-part@",
        "<local-part @ bad-domain (comment) . (comment com",
        "<local-part@[127.0"
    ]

    for raw in cases {
        let list = MessageIdList.parse(raw)
        #expect(list == nil)
        #expect(MessageIdList.parseMessageId(raw) == nil)
    }
}
