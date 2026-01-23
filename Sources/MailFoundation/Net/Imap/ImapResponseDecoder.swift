//
// ImapResponseDecoder.swift
//
// Incremental IMAP response decoder.
//

public struct ImapResponseDecoder: Sendable {
    private var lineBuffer = LineBuffer()

    public init() {}

    public mutating func append(_ bytes: [UInt8]) -> [ImapResponse] {
        let lines = lineBuffer.append(bytes)
        var responses: [ImapResponse] = []
        for line in lines {
            if let response = ImapResponse.parse(line) {
                responses.append(response)
            }
        }
        return responses
    }
}
