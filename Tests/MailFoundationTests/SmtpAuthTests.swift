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
