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
// Pop3CommandError.swift
//
// POP3 command error wrapper (ported from MailKit semantics).
//

/// An error that occurred when executing a POP3 command.
///
/// This error is thrown when a POP3 command fails with an `-ERR` response
/// from the server. It captures both the server's error message and any
/// additional context.
///
/// ## Usage
///
/// ```swift
/// do {
///     try store.retr(999)
/// } catch let error as Pop3CommandError {
///     print("Command failed: \(error.message)")
///     print("Server said: \(error.statusText)")
/// }
/// ```
///
/// ## Common Error Scenarios
///
/// - Invalid message number: "no such message"
/// - Authentication failure: "authentication failed"
/// - Mailbox locked: "maildrop already locked"
/// - Connection timeout: "connection timed out"
///
/// ## See Also
///
/// - ``Pop3MailStoreError`` for store-level errors
/// - ``Pop3Response`` for raw server responses
public struct Pop3CommandError: Error, Sendable, Equatable {
    /// A human-readable description of the error.
    ///
    /// This may be the same as `statusText` or may include additional context.
    public let message: String

    /// The raw status text from the server's `-ERR` response.
    public let statusText: String

    /// Initializes a new command error.
    ///
    /// - Parameters:
    ///   - statusText: The raw status text from the server.
    ///   - message: An optional human-readable message. Defaults to the status text.
    public init(statusText: String, message: String? = nil) {
        self.statusText = statusText
        self.message = message ?? statusText
    }
}
