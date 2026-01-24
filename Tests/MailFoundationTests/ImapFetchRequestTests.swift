import Testing
@testable import MailFoundation

@Test("FetchRequest serializes HeaderSet exclusions")
func fetchRequestHeaderSetExclusions() throws {
    var headers = try HeaderSet(headers: ["Subject", "Date"])
    try headers.setExclude(true)
    let request = FetchRequest(items: [], headers: headers)
    #expect(request.imapItemList == "BODY.PEEK[HEADER.FIELDS.NOT (SUBJECT DATE)]")
}

@Test("FetchRequest HeaderSet exclude ignores references when requested")
func fetchRequestHeaderSetExcludeReferences() throws {
    var headers = try HeaderSet(headers: ["References"])
    try headers.setExclude(true)
    let request = FetchRequest(items: [.references], headers: headers)
    #expect(request.imapItemList == "BODY.PEEK[HEADER]")
}

@Test("FetchRequest HeaderSet exclude with empty list fetches all headers")
func fetchRequestHeaderSetExcludeEmpty() throws {
    var headers = HeaderSet()
    try headers.setExclude(true)
    let request = FetchRequest(items: [], headers: headers)
    #expect(request.imapItemList == "BODY.PEEK[HEADER]")
}

@Test("FetchRequest HeaderSet includes references when requested")
func fetchRequestHeaderSetIncludeReferences() throws {
    let headers = try HeaderSet(headers: ["Subject"])
    let request = FetchRequest(items: [.references], headers: headers)
    #expect(request.imapItemList == "BODY.PEEK[HEADER.FIELDS (SUBJECT REFERENCES)]")
}
