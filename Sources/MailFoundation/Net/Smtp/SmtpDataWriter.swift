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
// SmtpDataWriter.swift
//
// Helpers for SMTP DATA dot-stuffing and termination.
//

public enum SmtpDataWriter {
    private static let cr: UInt8 = 0x0D
    private static let lf: UInt8 = 0x0A
    private static let dot: UInt8 = 0x2E

    public static func prepare(_ data: [UInt8]) -> [UInt8] {
        var output: [UInt8] = []
        output.reserveCapacity(data.count + 5)

        var atLineStart = true
        for byte in data {
            if atLineStart, byte == dot {
                output.append(dot)
            }
            output.append(byte)
            if byte == lf {
                atLineStart = true
            } else if byte != cr {
                atLineStart = false
            }
        }

        let terminator: [UInt8] = [cr, lf, dot, cr, lf]
        if output.count >= terminator.count, Array(output.suffix(terminator.count)) == terminator {
            return output
        }

        if output.count >= 2, Array(output.suffix(2)) == [cr, lf] {
            output.append(contentsOf: [dot, cr, lf])
        } else {
            output.append(contentsOf: terminator)
        }

        return output
    }
}
