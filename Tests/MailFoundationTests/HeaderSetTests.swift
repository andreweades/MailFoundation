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
