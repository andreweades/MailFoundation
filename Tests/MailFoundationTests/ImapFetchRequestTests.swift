import Testing
@testable import MailFoundation

@Test("FetchRequest serializes HeaderSet exclusions")
func fetchRequestHeaderSetExclusions() {
    var headers = HeaderSet(headers: ["Subject", "Date"])
    headers.exclude = true
    let request = FetchRequest(items: [], headers: headers)
    #expect(request.imapItemList == "BODY.PEEK[HEADER.FIELDS.NOT (SUBJECT DATE)]")
}

@Test("FetchRequest HeaderSet exclude ignores references when requested")
func fetchRequestHeaderSetExcludeReferences() {
    var headers = HeaderSet(headers: ["References"])
    headers.exclude = true
    let request = FetchRequest(items: [.references], headers: headers)
    #expect(request.imapItemList == "BODY.PEEK[HEADER]")
}

@Test("FetchRequest HeaderSet exclude with empty list fetches all headers")
func fetchRequestHeaderSetExcludeEmpty() {
    var headers = HeaderSet()
    headers.exclude = true
    let request = FetchRequest(items: [], headers: headers)
    #expect(request.imapItemList == "BODY.PEEK[HEADER]")
}

@Test("FetchRequest HeaderSet includes references when requested")
func fetchRequestHeaderSetIncludeReferences() {
    let headers = HeaderSet(headers: ["Subject"])
    let request = FetchRequest(items: [.references], headers: headers)
    #expect(request.imapItemList == "BODY.PEEK[HEADER.FIELDS (SUBJECT REFERENCES)]")
}
