//
// Pop3MultilineDecoder.swift
//
// Incremental POP3 multiline decoder.
//

public enum Pop3ResponseEvent: Sendable, Equatable {
    case single(Pop3Response)
    case multiline(Pop3Response, [String])
}

public struct Pop3MultilineDecoder: Sendable {
    private var lineBuffer = LineBuffer()
    private var pendingMultiline: Bool = false
    private var collectingData: Bool = false
    private var currentResponse: Pop3Response?
    private var dataLines: [String] = []

    public init() {}

    public mutating func expectMultiline() {
        pendingMultiline = true
    }

    public mutating func append(_ bytes: [UInt8]) -> [Pop3ResponseEvent] {
        let lines = lineBuffer.append(bytes)
        var events: [Pop3ResponseEvent] = []

        for line in lines {
            if collectingData {
                if line == "." {
                    if let response = currentResponse {
                        events.append(.multiline(response, dataLines))
                    }
                    resetMultiline()
                } else {
                    if line.hasPrefix("..") {
                        dataLines.append(String(line.dropFirst()))
                    } else {
                        dataLines.append(line)
                    }
                }
                continue
            }

            if pendingMultiline {
                if let response = Pop3Response.parse(line) {
                    if response.status == .ok {
                        currentResponse = response
                        collectingData = true
                    } else {
                        events.append(.single(response))
                        pendingMultiline = false
                    }
                }
                continue
            }

            if let response = Pop3Response.parse(line) {
                events.append(.single(response))
            }
        }

        return events
    }

    private mutating func resetMultiline() {
        pendingMultiline = false
        collectingData = false
        currentResponse = nil
        dataLines.removeAll(keepingCapacity: true)
    }
}
