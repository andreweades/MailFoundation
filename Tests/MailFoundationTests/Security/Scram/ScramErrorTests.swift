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
// ScramErrorTests.swift
//
// Tests for SCRAM error types.
//

import Foundation
import Testing

@testable import MailFoundation

@Test("SCRAM error - incompleteChallenge")
func scramErrorIncompleteChallenge() {
    let error = ScramError.incompleteChallenge("missing salt")
    if case .incompleteChallenge(let msg) = error {
        #expect(msg == "missing salt")
    } else {
        Issue.record("Expected incompleteChallenge")
    }
    #expect(error.errorDescription != nil)
    #expect(error.errorDescription!.contains("missing salt"))
}

@Test("SCRAM error - invalidChallenge")
func scramErrorInvalidChallenge() {
    let error = ScramError.invalidChallenge("bad nonce")
    if case .invalidChallenge(let msg) = error {
        #expect(msg == "bad nonce")
    } else {
        Issue.record("Expected invalidChallenge")
    }
    #expect(error.errorDescription != nil)
    #expect(error.errorDescription!.contains("bad nonce"))
}

@Test("SCRAM error - incorrectHash")
func scramErrorIncorrectHash() {
    let error = ScramError.incorrectHash("signature mismatch")
    if case .incorrectHash(let msg) = error {
        #expect(msg == "signature mismatch")
    } else {
        Issue.record("Expected incorrectHash")
    }
    #expect(error.errorDescription != nil)
    #expect(error.errorDescription!.contains("signature mismatch"))
}

@Test("SCRAM error - invalidBase64")
func scramErrorInvalidBase64() {
    let error = ScramError.invalidBase64
    #expect(error == ScramError.invalidBase64)
    #expect(error.errorDescription != nil)
    #expect(error.errorDescription!.contains("base64"))
}

@Test("SCRAM error - cryptoUnavailable")
func scramErrorCryptoUnavailable() {
    let error = ScramError.cryptoUnavailable
    #expect(error == ScramError.cryptoUnavailable)
    #expect(error.errorDescription != nil)
    #expect(error.errorDescription!.contains("cryptographic"))
}

@Test("SCRAM error - alreadyAuthenticated")
func scramErrorAlreadyAuthenticated() {
    let error = ScramError.alreadyAuthenticated
    #expect(error == ScramError.alreadyAuthenticated)
    #expect(error.errorDescription != nil)
    #expect(error.errorDescription!.contains("completed"))
}

@Test("SCRAM error equatable")
func scramErrorEquatable() {
    #expect(ScramError.invalidBase64 == ScramError.invalidBase64)
    #expect(ScramError.cryptoUnavailable == ScramError.cryptoUnavailable)
    #expect(ScramError.alreadyAuthenticated == ScramError.alreadyAuthenticated)
    #expect(ScramError.invalidBase64 != ScramError.cryptoUnavailable)
    #expect(ScramError.incompleteChallenge("a") == ScramError.incompleteChallenge("a"))
    #expect(ScramError.incompleteChallenge("a") != ScramError.incompleteChallenge("b"))
}
