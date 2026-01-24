import Testing
@testable import MailFoundation

@Test
func smtpStatusCodeRawValues() {
    #expect(SmtpStatusCode.systemStatus.rawValue == 211)
    #expect(SmtpStatusCode.ok.rawValue == 250)
    #expect(SmtpStatusCode.startMailInput.rawValue == 354)
    #expect(SmtpStatusCode.mailboxUnavailable.rawValue == 550)
}

@Test
func smtpStatusCodeAllowsUnknownValues() {
    let custom = SmtpStatusCode(rawValue: 299)
    #expect(custom.rawValue == 299)
}

@Test
func smtpResponseExposesStatusCodeAndResponseText() {
    let response = SmtpResponse(code: 250, lines: ["OK", "SIZE 1024"])
    #expect(response.statusCode == .ok)
    #expect(response.response == "OK\nSIZE 1024")
}
