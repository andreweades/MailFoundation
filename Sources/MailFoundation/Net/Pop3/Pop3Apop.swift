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
// Pop3Apop.swift
//
// APOP digest helpers.
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Provides APOP authentication support for POP3.
///
/// APOP (Authenticated Post Office Protocol) is an authentication mechanism
/// that avoids sending the password in clear text. Instead, the server provides
/// a unique timestamp in the greeting, and the client sends an MD5 digest of
/// the timestamp concatenated with the password.
///
/// ## Overview
///
/// APOP authentication works as follows:
/// 1. Server sends greeting with a timestamp: `+OK POP3 <1234.5678@example.com>`
/// 2. Client computes: `MD5(timestamp + password)`
/// 3. Client sends: `APOP username digest`
///
/// ## Security Note
///
/// While APOP is more secure than plain USER/PASS authentication, it still uses
/// MD5 which is considered weak. For modern deployments, prefer SASL authentication
/// with stronger mechanisms or use TLS encryption.
///
/// ## Usage
///
/// ```swift
/// // Check if APOP is available
/// if Pop3Apop.isAvailable {
///     let greeting = try store.connect()
///     if let challenge = greeting.apopChallenge {
///         let digest = Pop3Apop.digest(challenge: challenge, password: "secret")!
///         try store.authenticateApop(user: "user", digest: digest)
///     }
/// }
/// ```
///
/// ## See Also
///
/// - ``Pop3Response/apopChallenge`` for extracting the timestamp
/// - ``Pop3MailStore/authenticateApop(user:password:)`` for automatic APOP
public enum Pop3Apop {
    /// Whether APOP authentication is available on this platform.
    ///
    /// APOP requires CryptoKit for MD5 hashing. Returns `true` on platforms
    /// where CryptoKit is available.
    public static var isAvailable: Bool {
        #if canImport(CryptoKit)
        return true
        #else
        return false
        #endif
    }

    /// Computes the APOP digest for authentication.
    ///
    /// The digest is computed as: `MD5(challenge + password)` and returned
    /// as a lowercase hexadecimal string.
    ///
    /// - Parameters:
    ///   - challenge: The server's timestamp challenge (e.g., `<1234.5678@example.com>`).
    ///   - password: The user's password.
    /// - Returns: The MD5 digest as a hex string, or nil if CryptoKit is unavailable.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let challenge = "<1234.5678@example.com>"
    /// if let digest = Pop3Apop.digest(challenge: challenge, password: "secret") {
    ///     print(digest)  // "c4c9334bac560ecc979e58001b3e22fb"
    /// }
    /// ```
    public static func digest(challenge: String, password: String) -> String? {
        #if canImport(CryptoKit)
        let trimmedChallenge = challenge.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = trimmedChallenge + password
        let digest = Insecure.MD5.hash(data: Data(combined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        return nil
        #endif
    }
}

public extension Pop3Response {
    /// Computes the APOP digest using this response's challenge.
    ///
    /// This is a convenience method that extracts the APOP challenge from the
    /// response and computes the digest in one step.
    ///
    /// - Parameter password: The user's password.
    /// - Returns: The MD5 digest, or nil if no challenge is present or CryptoKit is unavailable.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let greeting = try store.connect()
    /// if let digest = greeting.apopDigest(password: "secret") {
    ///     try store.authenticateApop(user: "username", digest: digest)
    /// }
    /// ```
    func apopDigest(password: String) -> String? {
        guard let challenge = apopChallenge else { return nil }
        return Pop3Apop.digest(challenge: challenge, password: password)
    }
}
