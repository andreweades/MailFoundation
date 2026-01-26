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

@Test("HeaderSet validates field names")
func headerSetValidatesFieldNames() throws {
    let valid = [
        "Subject",
        "X-Custom-Header",
        "X_Alt",
        "List-ID",
        "DKIM-Signature"
    ]
    for field in valid {
        #expect(HeaderSet.isValidFieldName(field) == true)
    }

    let invalid = [
        "",
        "Subject:",
        "Sub ject",
        "Name\n",
        "Nämé"  // Non-ASCII characters not allowed per RFC 5322
    ]
    for field in invalid {
        #expect(HeaderSet.isValidFieldName(field) == false)
    }

    #expect(throws: HeaderSetError.invalidHeaderField("Subject:")) {
        _ = try HeaderSet(headers: ["Subject:"])
    }
    #expect(throws: HeaderSetError.invalidHeaderId) {
        var set = HeaderSet()
        _ = try set.add(.unknown)
    }
    #expect(throws: HeaderSetError.readOnly) {
        var set = HeaderSet.envelope
        _ = try set.add("X-Test")
    }
}

@Test("HeaderSet normalizes and preserves order")
func headerSetNormalizationAndOrder() throws {
    let set = try HeaderSet(headers: ["Subject", "Date", "subject"])
    #expect(set.orderedHeaders == ["SUBJECT", "DATE"])
}

@Test("HeaderSet presets")
func headerSetPresets() {
    #expect(HeaderSet.all.exclude == true)
    #expect(HeaderSet.all.isReadOnly == true)
    #expect(HeaderSet.references.contains("REFERENCES"))
    #expect(HeaderSet.envelope.contains("FROM"))
    #expect(HeaderSet.envelope.contains("TO"))
    #expect(HeaderSet.envelope.contains("MESSAGE-ID"))
}
