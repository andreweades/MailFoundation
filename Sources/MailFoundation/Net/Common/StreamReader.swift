//
// StreamReader.swift
//
// Simple InputStream reader helper.
//

import Foundation

public struct StreamReader {
    private let stream: InputStream
    private let bufferSize: Int

    public init(stream: InputStream, bufferSize: Int = 4096) {
        self.stream = stream
        self.bufferSize = max(1, bufferSize)
    }

    public mutating func readOnce() -> [UInt8] {
        var buffer = Array(repeating: UInt8(0), count: bufferSize)
        let count = stream.read(&buffer, maxLength: bufferSize)
        guard count > 0 else { return [] }
        return Array(buffer.prefix(count))
    }

    public mutating func readAll() -> [UInt8] {
        var data: [UInt8] = []
        while true {
            let chunk = readOnce()
            if chunk.isEmpty { break }
            data.append(contentsOf: chunk)
        }
        return data
    }
}
