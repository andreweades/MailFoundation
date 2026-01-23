//
// ImapMailboxEncoding.swift
//
// Modified UTF-7 encoding for IMAP mailbox names.
//

import Foundation

public enum ImapMailboxEncoding {
    public static func decode(_ text: String) -> String {
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            let ch = text[index]
            if ch == "&" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, text[nextIndex] == "-" {
                    result.append("&")
                    index = text.index(after: nextIndex)
                    continue
                }
                var encoded = ""
                var cursor = nextIndex
                while cursor < text.endIndex, text[cursor] != "-" {
                    encoded.append(text[cursor])
                    cursor = text.index(after: cursor)
                }
                if cursor < text.endIndex, text[cursor] == "-" {
                    let decoded = decodeModifiedBase64(encoded)
                    result.append(decoded)
                    index = text.index(after: cursor)
                    continue
                }
            }
            result.append(ch)
            index = text.index(after: index)
        }
        return result
    }

    public static func encode(_ text: String) -> String {
        var result = ""
        var buffer = ""

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            let encoded = encodeModifiedBase64(buffer)
            result.append("&")
            result.append(encoded)
            result.append("-")
            buffer.removeAll()
        }

        for scalar in text.unicodeScalars {
            if scalar.value >= 0x20 && scalar.value <= 0x7E {
                flushBuffer()
                if scalar == "&" {
                    result.append("&-")
                } else {
                    result.append(Character(scalar))
                }
            } else {
                buffer.unicodeScalars.append(scalar)
            }
        }

        flushBuffer()
        return result
    }

    private static func encodeModifiedBase64(_ text: String) -> String {
        let utf16 = Array(text.utf16)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(utf16.count * 2)
        for value in utf16 {
            bytes.append(UInt8((value >> 8) & 0xFF))
            bytes.append(UInt8(value & 0xFF))
        }
        let data = Data(bytes)
        let base64 = data.base64EncodedString()
        let modified = base64
            .replacingOccurrences(of: "/", with: ",")
            .replacingOccurrences(of: "=", with: "")
        return modified
    }

    private static func decodeModifiedBase64(_ text: String) -> String {
        var base64 = text.replacingOccurrences(of: ",", with: "/")
        let padding = (4 - (base64.count % 4)) % 4
        if padding > 0 {
            base64.append(String(repeating: "=", count: padding))
        }
        guard let data = Data(base64Encoded: base64) else {
            return ""
        }
        var utf16: [UInt16] = []
        utf16.reserveCapacity(data.count / 2)
        var index = data.startIndex
        while index < data.endIndex {
            let next = data.index(index, offsetBy: 2, limitedBy: data.endIndex) ?? data.endIndex
            guard next <= data.endIndex else { break }
            if next > data.endIndex { break }
            if index == data.endIndex { break }
            if data.distance(from: index, to: next) < 2 { break }
            let high = UInt16(data[index]) << 8
            let low = UInt16(data[data.index(after: index)])
            utf16.append(high | low)
            index = next
        }
        return String(utf16CodeUnits: utf16, count: utf16.count)
    }
}
