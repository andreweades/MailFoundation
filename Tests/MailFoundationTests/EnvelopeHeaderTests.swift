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
import MimeFoundation
@testable import MailFoundation

@Test("Envelope list-id normalization")
func envelopeListIdNormalization() {
    let headers = HeaderList()
    headers.add(Header(field: "List-Id", value: "Example List <list.example.com>"))
    let envelope = Envelope(headers: headers)
    #expect(envelope.listId == "list.example.com")
}

@Test("Envelope captures list + auth headers")
func envelopeHeaderExpansions() {
    let headers = HeaderList()
    headers.add(Header(field: "List-Owner", value: "<mailto:owner@example.com>"))
    headers.add(Header(field: "List-Unsubscribe-Post", value: "List-Unsubscribe=One-Click"))
    headers.add(Header(field: "ARC-Authentication-Results", value: "i=1; mx.example.com; spf=pass"))
    headers.add(Header(field: "ARC-Seal", value: "i=1; a=rsa-sha256; d=example.com; s=arc;"))
    headers.add(Header(field: "ARC-Message-Signature", value: "i=1; a=rsa-sha256; d=example.com; s=arc;"))
    headers.add(Header(field: "DomainKey-Signature", value: "a=rsa-sha1; d=example.com; s=mail;"))
    let envelope = Envelope(headers: headers)
    #expect(envelope.listOwner == "<mailto:owner@example.com>")
    #expect(envelope.listUnsubscribePost == "List-Unsubscribe=One-Click")
    #expect(envelope.arcAuthenticationResults.first == "i=1; mx.example.com; spf=pass")
    #expect(envelope.arcSeals.count == 1)
    #expect(envelope.arcMessageSignatures.count == 1)
    #expect(envelope.domainKeySignatures.count == 1)
}
