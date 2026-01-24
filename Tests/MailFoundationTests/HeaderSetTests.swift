import Testing
@testable import MailFoundation

@Test("HeaderSet validates field names")
func headerSetValidatesFieldNames() {
    let valid = [
        "Subject",
        "X-Custom-Header",
        "X_Alt",
        "List-ID",
        "DKIM-Signature",
        "Nämé"
    ]
    for field in valid {
        #expect(HeaderSet.isValidFieldName(field) == true)
    }

    let invalid = [
        "",
        "Subject:",
        "Sub ject",
        "Name\n"
    ]
    for field in invalid {
        #expect(HeaderSet.isValidFieldName(field) == false)
    }
}

@Test("HeaderSet normalizes and preserves order")
func headerSetNormalizationAndOrder() {
    let set = HeaderSet(headers: ["Subject", "Date", "subject"])
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
