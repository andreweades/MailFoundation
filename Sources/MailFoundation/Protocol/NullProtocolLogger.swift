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
// NullProtocolLogger.swift
//
// Ported from MailKit (C#) to Swift.
//

import Foundation

/// A protocol logger that does not log to anywhere.
///
/// `NullProtocolLogger` is a no-op implementation of the ``ProtocolLoggerType`` protocol
/// that silently discards all logged data. This is the default logger used by mail clients
/// when protocol logging is not required.
///
/// ## Overview
///
/// By default, the ``AsyncSmtpTransport``, ``Pop3MailStore``, ``AsyncPop3MailStore``,
/// ``ImapMailStore``, and ``AsyncImapMailStore`` all use a `NullProtocolLogger`.
/// This ensures that no protocol data is logged unless explicitly configured otherwise.
///
/// ## Usage
///
/// Use `NullProtocolLogger` when you want to disable logging or when you need to provide
/// a logger instance but do not want any output:
///
/// ```swift
/// // Create a mail store with logging disabled
/// let store = try ImapMailStore(
///     host: "imap.example.com",
///     port: 993,
///     logger: NullProtocolLogger()
/// )
///
/// // Or use it to temporarily disable logging
/// let nullLogger = NullProtocolLogger()
/// smtpClient.protocolLogger = nullLogger
/// ```
///
/// ## Performance
///
/// Since all methods are empty no-ops, `NullProtocolLogger` has minimal overhead and is
/// safe to use in production environments where protocol logging is not needed.
///
/// - SeeAlso: ``ProtocolLoggerType``
/// - SeeAlso: ``ProtocolLogger``
public final class NullProtocolLogger: ProtocolLoggerType {
    /// Creates a new `NullProtocolLogger` instance.
    ///
    /// The created logger discards all logged data without performing any operations.
    public init() {}

    /// The authentication secret detector.
    ///
    /// Gets or sets the authentication secret detector. Since `NullProtocolLogger` does not
    /// actually log any data, this property has no effect but is provided for protocol conformance.
    ///
    /// - Note: Setting this property does nothing because no data is logged.
    public var authenticationSecretDetector: AuthenticationSecretDetector?

    /// Logs a connection to the specified URI.
    ///
    /// This method does nothing. The URI is ignored.
    ///
    /// - Parameter uri: The URI that would be logged (ignored).
    public func logConnect(_ uri: URL) {
    }

    /// Logs a sequence of bytes sent by the client.
    ///
    /// This method does nothing. The buffer contents are ignored.
    ///
    /// - Parameters:
    ///   - buffer: The buffer containing bytes to log (ignored).
    ///   - offset: The offset of the first byte to log (ignored).
    ///   - count: The number of bytes to log (ignored).
    public func logClient(_ buffer: [UInt8], offset: Int, count: Int) {
    }

    /// Logs a sequence of bytes sent by the server.
    ///
    /// This method does nothing. The buffer contents are ignored.
    ///
    /// - Parameters:
    ///   - buffer: The buffer containing bytes to log (ignored).
    ///   - offset: The offset of the first byte to log (ignored).
    ///   - count: The number of bytes to log (ignored).
    public func logServer(_ buffer: [UInt8], offset: Int, count: Int) {
    }

    /// Closes the logger and releases any resources.
    ///
    /// This method does nothing since `NullProtocolLogger` does not hold any resources.
    public func close() {
    }
}
