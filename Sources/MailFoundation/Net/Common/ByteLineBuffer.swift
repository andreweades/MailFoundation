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
// ByteLineBuffer.swift
//
// Incremental CRLF line buffering for raw bytes.
//

public struct ByteLineBuffer: Sendable {
    private var buffer: [UInt8]

    public init(capacity: Int = 0) {
        self.buffer = []
        if capacity > 0 {
            buffer.reserveCapacity(capacity)
        }
    }

    public mutating func append(_ bytes: [UInt8]) -> [[UInt8]] {
        guard !bytes.isEmpty else { return [] }
        buffer.append(contentsOf: bytes)
        return drainLines()
    }

    private mutating func drainLines() -> [[UInt8]] {
        var lines: [[UInt8]] = []
        var start = 0
        var index = 0

        while index < buffer.count {
            if buffer[index] == 0x0A {
                var end = index
                if end > start, buffer[end - 1] == 0x0D {
                    end -= 1
                }
                let line = Array(buffer[start..<end])
                lines.append(line)
                index += 1
                start = index
            } else {
                index += 1
            }
        }

        if start > 0 {
            buffer.removeFirst(start)
        }

        return lines
    }
}
