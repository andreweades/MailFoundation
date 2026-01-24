import Testing
import SwiftMimeKit
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
