//
// SmtpResponseDecoder.swift
//
// Incremental SMTP response decoder.
//

public struct SmtpResponseDecoder: Sendable {
    private var lineBuffer = LineBuffer()
    private var parser = SmtpResponseParser()

    public init() {}

    public mutating func append(_ bytes: [UInt8]) -> [SmtpResponse] {
        let lines = lineBuffer.append(bytes)
        var responses: [SmtpResponse] = []
        for line in lines {
            if let response = parser.parseLine(line) {
                responses.append(response)
            }
        }
        return responses
    }
}
