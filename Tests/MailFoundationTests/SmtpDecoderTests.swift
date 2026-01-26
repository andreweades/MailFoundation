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

@Test("SMTP response decoder handles empty multiline segments")
func smtpResponseDecoderEmptySegments() {
    var decoder = SmtpResponseDecoder()
    let bytes = Array("250-\r\n250 OK\r\n".utf8)
    let responses = decoder.append(bytes)
    #expect(responses.count == 1)
    #expect(responses.first?.lines == ["", "OK"])
}

@Test("SMTP response decoder handles split replies across chunks")
func smtpResponseDecoderSplitChunks() {
    var decoder = SmtpResponseDecoder()
    let first = decoder.append(Array("250-PIPELIN".utf8))
    #expect(first.isEmpty)
    let second = decoder.append(Array("ING\r\n250 OK\r\n".utf8))
    #expect(second.count == 1)
    #expect(second.first?.lines == ["PIPELINING", "OK"])
}

@Test("SMTP response decoder preserves leading spaces in lines")
func smtpResponseDecoderLeadingSpaces() {
    var decoder = SmtpResponseDecoder()
    let bytes = Array("250- \r\n250  OK\r\n".utf8)
    let responses = decoder.append(bytes)
    #expect(responses.count == 1)
    #expect(responses.first?.lines == [" ", " OK"])
}

@Test("SMTP response decoder drops mixed reply code continuations")
func smtpResponseDecoderMixedReplyCodes() {
    var decoder = SmtpResponseDecoder()
    let bytes = Array("250-PIPELINING\r\n251 HELP\r\n".utf8)
    let responses = decoder.append(bytes)
    #expect(responses.count == 1)
    #expect(responses.first?.code == 251)
    #expect(responses.first?.lines == ["HELP"])
}

@Test("SMTP response decoder drops pending multiline on malformed line")
func smtpResponseDecoderSkipsMalformedLines() {
    var decoder = SmtpResponseDecoder()
    let bytes = Array("250-PIPELINING\r\n25X bad\r\n250 OK\r\n".utf8)
    let responses = decoder.append(bytes)
    #expect(responses.count == 1)
    #expect(responses.first?.code == 250)
    #expect(responses.first?.lines == ["OK"])
}

@Test("SMTP response decoder resets pending on malformed short line")
func smtpResponseDecoderMalformedShortLine() {
    var decoder = SmtpResponseDecoder()
    let bytes = Array("250-PIPELINING\r\nBAD\r\n250 OK\r\n".utf8)
    let responses = decoder.append(bytes)
    #expect(responses.count == 1)
    #expect(responses.first?.code == 250)
    #expect(responses.first?.lines == ["OK"])
}
