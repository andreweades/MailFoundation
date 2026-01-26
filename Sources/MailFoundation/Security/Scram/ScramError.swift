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
// ScramError.swift
//
// SCRAM authentication errors.
//

import Foundation

/// Errors that can occur during SCRAM authentication.
///
/// SCRAM (Salted Challenge Response Authentication Mechanism) is a
/// challenge-response authentication protocol defined in RFC 5802.
public enum ScramError: Error, Sendable, Equatable, LocalizedError {
    /// The server's challenge is missing required fields.
    case incompleteChallenge(String)

    /// The server's challenge contains invalid data.
    case invalidChallenge(String)

    /// The server's signature does not match the expected value.
    case incorrectHash(String)

    /// The input data is not valid base64.
    case invalidBase64

    /// The required cryptographic functions are not available.
    case cryptoUnavailable

    /// The SCRAM context has already completed authentication.
    case alreadyAuthenticated

    /// A localized description of the error.
    public var errorDescription: String? {
        switch self {
        case .incompleteChallenge(let detail):
            return "Incomplete SCRAM challenge: \(detail)"
        case .invalidChallenge(let detail):
            return "Invalid SCRAM challenge: \(detail)"
        case .incorrectHash(let detail):
            return "Incorrect SCRAM hash: \(detail)"
        case .invalidBase64:
            return "Invalid base64 encoding in SCRAM challenge"
        case .cryptoUnavailable:
            return "Required cryptographic functions are not available"
        case .alreadyAuthenticated:
            return "SCRAM authentication has already completed"
        }
    }
}
