//
// ImapLiteralDecoder.swift
//
// Incremental IMAP literal decoder.
//

public struct ImapLiteralMessage: Sendable, Equatable {
    public let line: String
    public let response: ImapResponse?
    public let literal: [UInt8]?
}

public struct ImapLiteralDecoder: Sendable {
    private var lineBuffer = LineBuffer()
    private var pendingLine: String?
    private var pendingLiteralBytes: Int = 0
    private var pendingLiteral: [UInt8] = []

    public init() {}

    public mutating func append(_ bytes: [UInt8]) -> [ImapLiteralMessage] {
        var remaining = bytes[...]
        var messages: [ImapLiteralMessage] = []

        while !remaining.isEmpty {
            if pendingLiteralBytes > 0 {
                let take = min(pendingLiteralBytes, remaining.count)
                pendingLiteral.append(contentsOf: remaining.prefix(take))
                pendingLiteralBytes -= take
                remaining = remaining.dropFirst(take)

                if pendingLiteralBytes == 0, let line = pendingLine {
                    messages.append(ImapLiteralMessage(line: line, response: ImapResponse.parse(line), literal: pendingLiteral))
                    pendingLine = nil
                    pendingLiteral.removeAll(keepingCapacity: true)
                }
                continue
            }

            let lines = lineBuffer.append(remaining)
            remaining = []
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if let literalLength = parseLiteralLength(from: trimmedLine) {
                    if literalLength == 0 {
                        messages.append(ImapLiteralMessage(line: trimmedLine, response: ImapResponse.parse(trimmedLine), literal: []))
                    } else {
                        pendingLine = trimmedLine
                        pendingLiteralBytes = literalLength
                        pendingLiteral.removeAll(keepingCapacity: true)
                    }
                } else {
                    messages.append(ImapLiteralMessage(line: trimmedLine, response: ImapResponse.parse(trimmedLine), literal: nil))
                }
            }
        }

        return messages
    }

    private func parseLiteralLength(from line: String) -> Int? {
        let bytes = Array(line.utf8)
        guard let last = bytes.last, last == 0x7D else { // '}'
            return nil
        }

        var index = bytes.count - 2
        var multiplier = 1
        var value = 0
        var sawDigit = false

        while index >= 0 {
            let byte = bytes[index]
            if byte == 0x7B { // '{'
                return sawDigit ? value : nil
            }
            if byte == 0x2B { // '+'
                index -= 1
                continue
            }
            if byte >= 0x30, byte <= 0x39 {
                sawDigit = true
                value += Int(byte - 0x30) * multiplier
                multiplier *= 10
                index -= 1
                continue
            }
            return nil
        }

        return nil
    }
}
