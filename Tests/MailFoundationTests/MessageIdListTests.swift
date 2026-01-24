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
