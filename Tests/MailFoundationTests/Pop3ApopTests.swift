import Testing
@testable import MailFoundation

@Test("POP3 APOP digest matches RFC example")
func pop3ApopDigestMatchesExample() {
    #if canImport(CryptoKit)
    let challenge = "<1896.697170952@dbc.mtview.ca.us>"
    let digest = Pop3Apop.digest(challenge: challenge, password: "tanstaaf")
    #expect(digest == "c4c9334bac560ecc979e58001b3e22fb")

    let response = Pop3Response.parse("+OK POP3 server ready \(challenge)")
    #expect(response?.apopDigest(password: "tanstaaf") == "c4c9334bac560ecc979e58001b3e22fb")
    #else
    #expect(Pop3Apop.digest(challenge: "<x>", password: "y") == nil)
    #endif
}
