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
