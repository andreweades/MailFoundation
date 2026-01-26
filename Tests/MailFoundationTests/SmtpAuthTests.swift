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

import Foundation
import Testing
@testable import MailFoundation

@Test("SMTP SASL PLAIN initial response")
func smtpSaslPlainInitialResponse() {
    let auth = SmtpSasl.plain(username: "user", password: "pass")
    #expect(auth.mechanism == "PLAIN")
    #expect(auth.initialResponse != nil)
    guard let initial = auth.initialResponse,
          let data = Data(base64Encoded: initial),
          let decoded = String(data: data, encoding: .utf8) else {
        #expect(Bool(false))
        return
    }
    #expect(decoded == "\u{0}user\u{0}pass")
}

@Test("SMTP SASL LOGIN responder")
func smtpSaslLoginResponder() throws {
    let auth = SmtpSasl.login(username: "user", password: "pass")
    guard let responder = auth.responder else {
        #expect(Bool(false))
        return
    }
    let userChallenge = Data("Username:".utf8).base64EncodedString()
    let passChallenge = Data("Password:".utf8).base64EncodedString()
    #expect(try responder(userChallenge) == Data("user".utf8).base64EncodedString())
    #expect(try responder(passChallenge) == Data("pass".utf8).base64EncodedString())
}

@Test("SMTP SASL XOAUTH2 initial response")
func smtpSaslXoauth2InitialResponse() {
    let auth = SmtpSasl.xoauth2(username: "user", accessToken: "token")
    #expect(auth.mechanism == "XOAUTH2")
    #expect(auth.initialResponse != nil)
    guard let initial = auth.initialResponse,
          let data = Data(base64Encoded: initial),
          let decoded = String(data: data, encoding: .utf8) else {
        #expect(Bool(false))
        return
    }
    #expect(decoded == "user=user\u{01}auth=Bearer token\u{01}\u{01}")
}

@Test("SMTP session AUTH LOGIN via SASL helper")
func smtpSessionAuthLoginWithHelper() throws {
    let transport = TestTransport(incoming: [
        Array("220 Ready\r\n".utf8),
        Array("334 VXNlcm5hbWU6\r\n".utf8),
        Array("334 UGFzc3dvcmQ6\r\n".utf8),
        Array("235 2.7.0 Auth OK\r\n".utf8)
    ])
    let session = SmtpSession(transport: transport, maxReads: 4)
    _ = try session.connect()

    let auth = SmtpSasl.login(username: "user", password: "pass")
    let response = try session.authenticate(auth)
    #expect(response.code == 235)

    let userBase64 = Data("user".utf8).base64EncodedString()
    let passBase64 = Data("pass".utf8).base64EncodedString()
    let sent = transport.written.map { String(decoding: $0, as: UTF8.self) }
    #expect(sent.first == "AUTH LOGIN\r\n")
    #expect(sent.dropFirst().first == "\(userBase64)\r\n")
    #expect(sent.dropFirst(2).first == "\(passBase64)\r\n")
}
