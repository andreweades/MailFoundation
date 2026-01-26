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
// NtlmChallengeMessageTests.swift
//
// Tests for NTLM Type 2 (Challenge) message.
//

import Foundation
import Testing

@testable import MailFoundation

@Test("NTLM Challenge message decode basic")
func ntlmChallengeDecodeBasic() throws {
    // Minimal valid Type 2 message with server challenge
    var data = Data(count: 56)
    // Signature
    let sig: [UInt8] = [0x4E, 0x54, 0x4C, 0x4D, 0x53, 0x53, 0x50, 0x00]
    for (i, b) in sig.enumerated() {
        data[i] = b
    }
    // Type 2
    data[8] = 0x02
    data[9] = 0x00
    data[10] = 0x00
    data[11] = 0x00
    // Flags at offset 20 (NegotiateUnicode | NegotiateNtlm)
    data[20] = 0x01
    data[21] = 0x02
    data[22] = 0x00
    data[23] = 0x00
    // Server challenge at offset 24 (8 bytes)
    for i in 0..<8 {
        data[24 + i] = UInt8(i + 1)  // 01 02 03 04 05 06 07 08
    }

    let challenge = try NtlmChallengeMessage(data: data)

    #expect(challenge.type == 2)
    #expect(challenge.serverChallenge.count == 8)
    #expect(Array(challenge.serverChallenge) == [1, 2, 3, 4, 5, 6, 7, 8])
}

@Test("NTLM Challenge message decode with target name")
func ntlmChallengeWithTargetName() throws {
    // Build a Type 2 message with target name "TEST"
    let targetNameStr = "TEST".data(using: .utf16LittleEndian)!
    let targetNameOffset = 56

    var data = Data(count: targetNameOffset + targetNameStr.count)
    // Signature
    let sig: [UInt8] = [0x4E, 0x54, 0x4C, 0x4D, 0x53, 0x53, 0x50, 0x00]
    for (i, b) in sig.enumerated() {
        data[i] = b
    }
    // Type 2
    data[8] = 0x02

    // Target name security buffer at offset 12
    data[12] = UInt8(targetNameStr.count)
    data[13] = 0x00
    data[14] = UInt8(targetNameStr.count)
    data[15] = 0x00
    // Offset = 56
    data[16] = UInt8(targetNameOffset)
    data[17] = 0x00
    data[18] = 0x00
    data[19] = 0x00

    // Flags at offset 20 (NegotiateUnicode)
    data[20] = 0x01
    data[21] = 0x00
    data[22] = 0x00
    data[23] = 0x00

    // Server challenge at offset 24
    for i in 0..<8 {
        data[24 + i] = UInt8(0x11 + i)
    }

    // Target name payload at offset 56
    for (i, b) in targetNameStr.enumerated() {
        data[targetNameOffset + i] = b
    }

    let challenge = try NtlmChallengeMessage(data: data)

    #expect(challenge.type == 2)
    #expect(challenge.targetName == "TEST")
    #expect(challenge.flags.contains(.negotiateUnicode))
}

@Test("NTLM Challenge message too short throws")
func ntlmChallengeTooShort() {
    let shortData = Data([0x4E, 0x54, 0x4C, 0x4D, 0x53, 0x53, 0x50, 0x00, 0x02, 0x00, 0x00, 0x00])

    #expect(throws: NtlmError.messageTooShort) {
        _ = try NtlmChallengeMessage(data: shortData)
    }
}

@Test("NTLM Challenge message invalid signature throws")
func ntlmChallengeInvalidSignature() {
    var data = Data(count: 32)
    // Wrong signature
    data[0] = 0x00
    data[8] = 0x02

    #expect(throws: NtlmError.invalidSignature) {
        _ = try NtlmChallengeMessage(data: data)
    }
}

@Test("NTLM Challenge encode roundtrip")
func ntlmChallengeEncodeRoundtrip() throws {
    // Create a challenge message by decoding
    var data = Data(count: 56)
    let sig: [UInt8] = [0x4E, 0x54, 0x4C, 0x4D, 0x53, 0x53, 0x50, 0x00]
    for (i, b) in sig.enumerated() {
        data[i] = b
    }
    data[8] = 0x02
    data[20] = 0x01  // NegotiateUnicode
    data[21] = 0x02  // NegotiateNtlm
    for i in 0..<8 {
        data[24 + i] = UInt8(0xAA + i)
    }

    let original = try NtlmChallengeMessage(data: data)
    let encoded = original.encode()
    let decoded = try NtlmChallengeMessage(data: encoded)

    #expect(decoded.type == 2)
    #expect(decoded.serverChallenge == original.serverChallenge)
}
