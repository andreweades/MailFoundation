//
// AuthenticationSecretDetector.swift
//
// Ported from MailKit (C#) to Swift.
//

/// An authentication secret representing a range within a buffer that should be redacted.
///
/// `AuthenticationSecret` identifies a contiguous range of bytes in a buffer that contains
/// sensitive authentication data such as passwords, OAuth tokens, or other credentials.
/// The ``ProtocolLogger`` uses this information to redact secrets from protocol logs.
///
/// ## Overview
///
/// When an ``AuthenticationSecretDetector`` detects sensitive data in a buffer,
/// it returns an array of `AuthenticationSecret` values indicating which byte ranges
/// should be masked. Each secret specifies a starting index and length within the buffer.
///
/// ## Example
///
/// ```swift
/// // Create a secret representing bytes 10-20 in a buffer
/// let secret = AuthenticationSecret(startIndex: 10, length: 10)
/// ```
///
/// - SeeAlso: ``AuthenticationSecretDetector``
/// - SeeAlso: ``ProtocolLogger``
public struct AuthenticationSecret: Sendable, Hashable {
    /// The starting offset of the secret within a buffer.
    ///
    /// This value represents the zero-based index of the first byte of the secret
    /// data within the buffer that was scanned by the secret detector.
    public let startIndex: Int

    /// The length of the secret within a buffer.
    ///
    /// This value represents the number of bytes that comprise the secret data,
    /// starting at ``startIndex``.
    public let length: Int

    /// Creates a new `AuthenticationSecret` with the specified range.
    ///
    /// - Parameters:
    ///   - startIndex: The zero-based starting index of the secret within the buffer.
    ///   - length: The number of bytes that comprise the secret.
    public init(startIndex: Int, length: Int) {
        self.startIndex = startIndex
        self.length = length
    }
}

/// A protocol for detecting authentication secrets within protocol data.
///
/// `AuthenticationSecretDetector` implementations analyze buffers of protocol data
/// to identify sensitive authentication information that should be redacted from logs.
///
/// ## Overview
///
/// When a ``ProtocolLogger`` has its ``ProtocolLogger/redactSecrets`` property set to `true`,
/// it uses the configured `AuthenticationSecretDetector` to identify authentication secrets
/// in client data before writing to the log. Any detected secrets are replaced with asterisks
/// (`********`) in the log output.
///
/// ## Implementing a Custom Detector
///
/// To create a custom secret detector, implement this protocol and provide logic
/// to identify secrets specific to your authentication mechanism.
///
/// ```swift
/// class MyCustomSecretDetector: AuthenticationSecretDetector {
///     func detectSecrets(in buffer: [UInt8], offset: Int, count: Int) -> [AuthenticationSecret] {
///         // Analyze the buffer and return any detected secrets
///         var secrets: [AuthenticationSecret] = []
///
///         // Example: detect a password after "PASS " command
///         let passPrefix = Array("PASS ".utf8)
///         if count > passPrefix.count {
///             let slice = Array(buffer[offset..<(offset + min(passPrefix.count, count))])
///             if slice == passPrefix {
///                 // The password starts after "PASS " and extends to end of line
///                 let secretStart = offset + passPrefix.count
///                 let secretLength = count - passPrefix.count
///                 secrets.append(AuthenticationSecret(startIndex: secretStart, length: secretLength))
///             }
///         }
///
///         return secrets
///     }
/// }
/// ```
///
/// ## Usage with Protocol Logger
///
/// ```swift
/// let logger = try ProtocolLogger(filePath: "/tmp/smtp.log")
/// logger.authenticationSecretDetector = MyCustomSecretDetector()
/// logger.redactSecrets = true
/// ```
///
/// - Note: The mail service implementations (SMTP, IMAP, POP3) automatically configure
///   appropriate secret detectors for standard authentication mechanisms.
///
/// - SeeAlso: ``AuthenticationSecret``
/// - SeeAlso: ``ProtocolLogger``
public protocol AuthenticationSecretDetector: AnyObject {
    /// Detects a list of secrets within a buffer.
    ///
    /// This method analyzes the specified portion of the buffer to identify
    /// any authentication secrets that should be redacted from protocol logs.
    ///
    /// - Parameters:
    ///   - buffer: The byte buffer to scan for secrets.
    ///   - offset: The zero-based starting index within the buffer to begin scanning.
    ///   - count: The number of bytes to scan, starting from `offset`.
    ///
    /// - Returns: An array of ``AuthenticationSecret`` values identifying the byte ranges
    ///   that contain sensitive data. Returns an empty array if no secrets are detected.
    ///
    /// - Note: The returned secrets should have `startIndex` values that fall within
    ///   the range `[offset, offset + count)`.
    func detectSecrets(in buffer: [UInt8], offset: Int, count: Int) -> [AuthenticationSecret]
}

/// Type alias for compatibility with MailKit naming conventions.
///
/// This alias allows code ported from MailKit to use the familiar
/// `IAuthenticationSecretDetector` name from the C# implementation.
public typealias IAuthenticationSecretDetector = AuthenticationSecretDetector
