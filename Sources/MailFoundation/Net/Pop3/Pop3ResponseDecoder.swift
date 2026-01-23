//
// Pop3ResponseDecoder.swift
//
// Incremental POP3 response decoder.
//

public struct Pop3ResponseDecoder: Sendable {
    private var lineBuffer = LineBuffer()

    public init() {}

    public mutating func append(_ bytes: [UInt8]) -> [Pop3Response] {
        let lines = lineBuffer.append(bytes)
        var responses: [Pop3Response] = []
        for line in lines {
            if let response = Pop3Response.parse(line) {
                responses.append(response)
            }
        }
        return responses
    }
}
