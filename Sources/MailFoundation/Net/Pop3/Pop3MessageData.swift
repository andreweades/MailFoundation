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

//
// Pop3MessageData.swift
//
// Richer POP3 TOP/RETR response helpers.
//

import Foundation
import MimeFoundation

/// The result of a RETR or TOP command, containing the response and message data.
///
/// `Pop3MessageData` provides convenient methods for working with downloaded
/// message data, including header parsing and MIME message conversion.
///
/// ## Overview
///
/// This struct is returned by methods like ``Pop3Folder/retrData(_:)`` and
/// ``Pop3Folder/topData(_:lines:)``. It contains both the server's response
/// and the raw message bytes, with helper methods for common operations.
///
/// ## Usage
///
/// ```swift
/// // Download a message
/// let messageData = try folder.retrData(1)
///
/// // Parse as a MIME message
/// let message = try messageData.message()
/// print("Subject: \(message.subject ?? "No subject")")
///
/// // Or just get headers
/// let headers = messageData.parseHeaders()
/// if let subject = headers["Subject"]?.value {
///     print("Subject: \(subject)")
/// }
///
/// // Access raw bytes
/// let rawMessage = messageData.data
/// let headerBytes = messageData.headerBytes()
/// let bodyBytes = messageData.bodyBytes()
///
/// // Convert to string
/// if let text = messageData.string() {
///     print(text)
/// }
/// ```
///
/// ## See Also
///
/// - ``Pop3Folder/retrData(_:)`` for downloading messages
/// - ``Pop3Folder/topData(_:lines:)`` for downloading headers and previews
public struct Pop3MessageData: Sendable, Equatable {
    /// The server's response to the RETR or TOP command.
    public let response: Pop3Response

    /// The raw message data as bytes.
    ///
    /// For RETR, this is the complete message. For TOP, this includes the headers
    /// and the requested number of body lines.
    public let data: [UInt8]

    /// Initializes message data with a response and raw bytes.
    ///
    /// - Parameters:
    ///   - response: The server's response.
    ///   - data: The raw message bytes.
    public init(response: Pop3Response, data: [UInt8]) {
        self.response = response
        self.data = data
    }

    /// Extracts the header portion of the message as raw bytes.
    ///
    /// Headers are separated from the body by a blank line (CRLF CRLF).
    ///
    /// - Returns: The header bytes, not including the separating blank line.
    public func headerBytes() -> [UInt8] {
        Pop3HeaderParser.split(data).headers
    }

    /// Extracts the body portion of the message as raw bytes.
    ///
    /// - Returns: The body bytes, or an empty array if no body is present.
    public func bodyBytes() -> [UInt8] {
        Pop3HeaderParser.split(data).body
    }

    /// Parses the message headers.
    ///
    /// This method parses the header portion of the message and returns
    /// a ``HeaderList`` for easy access to individual headers.
    ///
    /// - Returns: The parsed headers.
    public func parseHeaders() -> HeaderList {
        Pop3HeaderParser.parse(data).headers
    }

    /// Parses both headers and extracts the body bytes.
    ///
    /// - Returns: A tuple containing the parsed headers and raw body bytes.
    public func parseHeaderBody() -> (headers: HeaderList, body: [UInt8]) {
        Pop3HeaderParser.parse(data)
    }

    /// Parses the data as a complete MIME message.
    ///
    /// - Parameter options: Parser options for controlling MIME parsing behavior.
    /// - Returns: The parsed ``MimeMessage``.
    /// - Throws: An error if the data cannot be parsed as a valid MIME message.
    public func message(options: ParserOptions = .default) throws -> MimeMessage {
        let stream = MemoryStream(data, writable: false)
        return try MimeMessage.load(options, stream)
    }

    /// Converts the message data to a string.
    ///
    /// - Parameter encoding: The string encoding to use (default: UTF-8).
    /// - Returns: The message as a string, or nil if the encoding fails.
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
