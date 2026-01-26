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

@Test("IMAP ESEARCH parses ALL with UID")
func imapESearchParsesAll() {
    let response = ImapESearchResponse.parse("* ESEARCH UID ALL 1:3")
    #expect(response?.isUid == true)
    #expect(response?.ids == [1, 2, 3])
}

@Test("IMAP ESEARCH parses COUNT and ranges")
func imapESearchParsesCount() {
    let response = ImapESearchResponse.parse("* ESEARCH (TAG \"A1\") ALL 2,4:5 COUNT 3")
    #expect(response?.isUid == false)
    #expect(response?.ids == [2, 4, 5])
    #expect(response?.count == 3)
}

@Test("IMAP ESEARCH parses MIN/MAX")
func imapESearchParsesMinMax() {
    let response = ImapESearchResponse.parse("* ESEARCH MIN 2 MAX 9")
    #expect(response?.min == 2)
    #expect(response?.max == 9)
}
