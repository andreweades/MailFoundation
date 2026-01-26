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

@Test
func parseEnhancedStatusCodeToken() {
    let code = SmtpEnhancedStatusCode("2.1.5")
    #expect(code != nil)
    #expect(code?.klass == 2)
    #expect(code?.subject == 1)
    #expect(code?.detail == 5)
    #expect(code?.description == "2.1.5")
}

@Test
func parseEnhancedStatusCodeInvalidToken() {
    #expect(SmtpEnhancedStatusCode("2.1") == nil)
    #expect(SmtpEnhancedStatusCode("2.1.x") == nil)
    #expect(SmtpEnhancedStatusCode("2..5") == nil)
}

@Test
func enhancedStatusCodesFromResponseLines() {
    let response = SmtpResponse(code: 250, lines: [
        "2.1.5 Ok",
        "SIZE 1024",
        " 2.1.0 Sender ok"
    ])

    let codes = response.enhancedStatusCodes
    #expect(codes.count == 2)
    #expect(codes.first == SmtpEnhancedStatusCode("2.1.5"))
    #expect(codes.last == SmtpEnhancedStatusCode("2.1.0"))
    #expect(response.enhancedStatusCode == SmtpEnhancedStatusCode("2.1.5"))
}
