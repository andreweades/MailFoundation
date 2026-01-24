//
// Pop3MessageData.swift
//
// Richer POP3 TOP/RETR response helpers.
//

import Foundation
import MimeFoundation

public struct Pop3MessageData: Sendable, Equatable {
    public let response: Pop3Response
    public let data: [UInt8]

    public init(response: Pop3Response, data: [UInt8]) {
        self.response = response
        self.data = data
    }

    public func headerBytes() -> [UInt8] {
        Pop3HeaderParser.split(data).headers
    }

    public func bodyBytes() -> [UInt8] {
        Pop3HeaderParser.split(data).body
    }

    public func parseHeaders() -> HeaderList {
        Pop3HeaderParser.parse(data).headers
    }

    public func parseHeaderBody() -> (headers: HeaderList, body: [UInt8]) {
        Pop3HeaderParser.parse(data)
    }

    public func message(options: ParserOptions = .default) throws -> MimeMessage {
        let stream = MemoryStream(data, writable: false)
        return try MimeMessage.load(options, stream)
    }

    public func string(encoding: String.Encoding = .utf8) -> String? {
        String(data: Data(data), encoding: encoding)
    }
}

private enum Pop3HeaderParser {
    static func split(_ bytes: [UInt8]) -> (headers: [UInt8], body: [UInt8]) {
        let separator = findHeaderBodySeparator(bytes)
        let headerBytes: [UInt8]
        let bodyBytes: [UInt8]

        if let separator {
            headerBytes = Array(bytes[0..<separator.headerEnd])
            bodyBytes = Array(bytes[separator.bodyStart..<bytes.count])
        } else {
            headerBytes = bytes
            bodyBytes = []
        }

        return (headerBytes, bodyBytes)
    }

    static func parse(_ bytes: [UInt8]) -> (headers: HeaderList, body: [UInt8]) {
        let (headerBytes, bodyBytes) = split(bytes)
        let headerList = HeaderList()
        guard let text = String(data: Data(headerBytes), encoding: .isoLatin1) else {
            return (headerList, bodyBytes)
        }

        var currentField: String? = nil
        var currentValue = ""
        let lines = text.components(separatedBy: "\n")
        for rawLine in lines {
            var line = rawLine
            if line.hasSuffix("\r") {
                line.removeLast()
            }
            if line.isEmpty {
                break
            }
            if line.first == " " || line.first == "\t" {
                if currentField != nil {
                    currentValue.append(line)
                }
                continue
            }

            if let field = currentField, let header = try? Header(validating: field, value: currentValue) {
                headerList.add(header)
            }

            guard let colon = line.firstIndex(of: ":") else {
                currentField = nil
                currentValue = ""
                continue
            }

            let field = line[..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
            let valueStart = line.index(after: colon)
            let value = line[valueStart...].trimmingCharacters(in: .whitespacesAndNewlines)
            currentField = field.isEmpty ? nil : field
            currentValue = String(value)
        }

        if let field = currentField, let header = try? Header(validating: field, value: currentValue) {
            headerList.add(header)
        }

        if findHeaderBodySeparator(bytes) == nil && headerList.isEmpty {
            return (headerList, bytes)
        }

        return (headerList, bodyBytes)
    }

    private static func findHeaderBodySeparator(_ bytes: [UInt8]) -> (headerEnd: Int, bodyStart: Int)? {
        if bytes.count < 2 {
            return nil
        }
        var index = 0
        while index + 1 < bytes.count {
            if bytes[index] == 0x0D, bytes[index + 1] == 0x0A {
                if index + 3 < bytes.count,
                   bytes[index + 2] == 0x0D,
                   bytes[index + 3] == 0x0A {
                    return (index, index + 4)
                }
            }
            if bytes[index] == 0x0A, bytes[index + 1] == 0x0A {
                return (index, index + 2)
            }
            index += 1
        }
        return nil
    }
}
