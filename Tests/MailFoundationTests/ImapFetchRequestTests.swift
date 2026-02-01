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

@Test("FetchRequest preview options")
func fetchRequestPreviewOptions() {
    let defaultPreview = FetchRequest(items: [.previewText])
    #expect(defaultPreview.imapItemList == "PREVIEW")

    let lazyPreview = FetchRequest(items: [.previewText], previewOptions: .lazy)
    #expect(lazyPreview.imapItemList == "PREVIEW (LAZY)")

    let fallback = FetchRequest(items: [.previewText], previewOptions: .lazy)
    #expect(fallback.imapItemList(previewFallback: ImapFetchPartial(start: 0, length: 64)) == "BODY.PEEK[TEXT]<0.64>")
}
