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
