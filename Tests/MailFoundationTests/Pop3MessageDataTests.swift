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
import MimeFoundation
@testable import MailFoundation

@Test("POP3 message data header parsing")
func pop3MessageDataHeaderParsing() throws {
    let data = Array("Subject: Hello\r\nFrom: sender@example.com\r\n\r\nBody".utf8)
    let response = Pop3Response(status: .ok, message: "OK")
    let messageData = Pop3MessageData(response: response, data: data)

    let (headers, body) = messageData.parseHeaderBody()
    #expect(headers[.subject] == "Hello")
    #expect(headers[.from] == "sender@example.com")
    #expect(body == Array("Body".utf8))
}

@Test("POP3 message data MimeMessage parsing")
func pop3MessageDataMessageParsing() throws {
    let data = Array("Subject: Hello\r\n\r\nBody".utf8)
    let response = Pop3Response(status: .ok, message: "OK")
    let messageData = Pop3MessageData(response: response, data: data)

    let message = try messageData.message()
    #expect(message.headers[.subject] == "Hello")
}
