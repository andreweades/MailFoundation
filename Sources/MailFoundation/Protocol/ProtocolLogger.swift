//
// ProtocolLogger.swift
//
// Ported from MailKit (C#) to Swift.
//

import Foundation

/// A protocol for logging the communication between a mail client and server.
///
/// `ProtocolLoggerType` defines the interface for protocol logging implementations.
/// It provides methods to log connection events, client-sent data, and server-sent data.
///
/// ## Overview
///
/// Protocol loggers are used by mail clients (SMTP, IMAP, POP3) to capture the raw
/// protocol communication for debugging and diagnostics. The logger receives the
/// exact bytes that are sent to and received from the server.
///
/// ## Implementing a Custom Logger
///
/// To create a custom protocol logger, implement this protocol:
///
/// ```swift
/// class ConsoleProtocolLogger: ProtocolLoggerType {
///     var authenticationSecretDetector: AuthenticationSecretDetector?
///
///     func logConnect(_ uri: URL) {
///         print("Connected to: \(uri)")
///     }
///
///     func logClient(_ buffer: [UInt8], offset: Int, count: Int) {
///         let data = Data(buffer[offset..<(offset + count)])
///         if let text = String(data: data, encoding: .utf8) {
///             print("C: \(text)", terminator: "")
///         }
///     }
///
///     func logServer(_ buffer: [UInt8], offset: Int, count: Int) {
///         let data = Data(buffer[offset..<(offset + count)])
///         if let text = String(data: data, encoding: .utf8) {
///             print("S: \(text)", terminator: "")
///         }
///     }
///
///     func close() {
///         print("Logger closed")
///     }
/// }
/// ```
///
/// ## Usage with Mail Clients
///
/// ```swift
/// // Use with an IMAP client
/// let logger = try ProtocolLogger(filePath: "/tmp/imap-debug.log")
/// let imapStore = try AsyncImapMailStore(
///     host: "imap.example.com",
///     port: 993,
///     logger: logger
/// )
/// ```
///
/// - SeeAlso: ``ProtocolLogger``
/// - SeeAlso: ``NullProtocolLogger``
/// - SeeAlso: ``AuthenticationSecretDetector``
public protocol ProtocolLoggerType: AnyObject {
    /// The authentication secret detector used to identify sensitive data in client messages.
    ///
    /// When set, the logger can use this detector to identify and potentially redact
    /// authentication secrets from the logged output.
    var authenticationSecretDetector: AuthenticationSecretDetector? { get set }

    /// Logs a connection to the specified URI.
    ///
    /// This method is called when the mail client establishes a connection to a server.
    ///
    /// - Parameter uri: The URI of the server being connected to.
    func logConnect(_ uri: URL)

    /// Logs a sequence of bytes sent by the client.
    ///
    /// This method is called by the mail service upon every successful write operation
    /// to its underlying network stream, passing the exact buffer, offset, and count
    /// arguments used in the write.
    ///
    /// - Parameters:
    ///   - buffer: The buffer containing bytes to log.
    ///   - offset: The zero-based offset of the first byte to log.
    ///   - count: The number of bytes to log.
    func logClient(_ buffer: [UInt8], offset: Int, count: Int)

    /// Logs a sequence of bytes sent by the server.
    ///
    /// This method is called by the mail service upon every successful read of its
    /// underlying network stream with the exact buffer that was read.
    ///
    /// - Parameters:
    ///   - buffer: The buffer containing bytes to log.
    ///   - offset: The zero-based offset of the first byte to log.
    ///   - count: The number of bytes to log.
    func logServer(_ buffer: [UInt8], offset: Int, count: Int)

    /// Closes the logger and releases any resources.
    ///
    /// After calling this method, the logger should not be used for further logging.
    func close()
}

/// Type alias for compatibility with MailKit naming conventions.
///
/// This alias allows code ported from MailKit to use the familiar
/// `IProtocolLogger` name from the C# implementation.
public typealias IProtocolLogger = ProtocolLoggerType

/// Errors that can occur during protocol logging operations.
///
/// These errors are thrown by ``ProtocolLogger`` when initialization fails
/// or when write operations encounter problems.
public enum ProtocolLoggerError: Error, Sendable {
    /// The provided arguments are invalid (e.g., negative offset or count).
    case invalidArguments

    /// The output stream could not be opened for writing.
    ///
    /// This error occurs when the logger cannot create or open the specified
    /// file or stream for writing protocol data.
    case unableToOpenStream

    /// A write operation to the output stream failed.
    case writeFailed
}

/// A default protocol logger for logging the communication between a mail client and server.
///
/// `ProtocolLogger` writes protocol communication to a file or stream, with support for
/// timestamps, customizable prefixes, and automatic redaction of authentication secrets.
///
/// ## Overview
///
/// Use `ProtocolLogger` to capture SMTP, IMAP, or POP3 protocol communication for
/// debugging purposes. The logger formats output with configurable prefixes for
/// client and server messages, optionally includes timestamps, and can automatically
/// redact sensitive authentication data.
///
/// ## Basic Usage
///
/// ```swift
/// // Log to a file
/// let logger = try ProtocolLogger(filePath: "/tmp/smtp-debug.log")
///
/// // Use with an SMTP client
/// let smtp = try AsyncSmtpTransport(
///     host: "smtp.example.com",
///     port: 465,
///     logger: logger
/// )
///
/// // ... perform mail operations ...
///
/// // Close the logger when done
/// logger.close()
/// ```
///
/// ## Output Format
///
/// The default output format uses "C: " prefix for client messages and "S: " for
/// server messages:
///
/// ```
/// Connected to smtp://smtp.example.com:465/
/// C: EHLO example.com
/// S: 250-smtp.example.com Hello
/// S: 250-AUTH LOGIN PLAIN
/// S: 250 OK
/// C: AUTH PLAIN ********
/// S: 235 Authentication successful
/// ```
///
/// ## Enabling Timestamps
///
/// ```swift
/// let logger = try ProtocolLogger(filePath: "/tmp/imap.log")
/// logger.logTimestamps = true
/// logger.timestampFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
///
/// // Output will include timestamps:
/// // 2024-01-15T10:30:45Z C: LOGIN user@example.com ********
/// // 2024-01-15T10:30:46Z S: OK LOGIN completed
/// ```
///
/// ## Secret Redaction
///
/// By default, `ProtocolLogger` redacts authentication secrets (passwords, tokens)
/// from client messages, replacing them with asterisks. This behavior is controlled
/// by the ``redactSecrets`` property and requires an ``authenticationSecretDetector``
/// to be configured.
///
/// ```swift
/// // Disable secret redaction (not recommended for production logs)
/// logger.redactSecrets = false
/// ```
///
/// ## Custom Prefixes
///
/// ```swift
/// let logger = try ProtocolLogger(filePath: "/tmp/mail.log")
/// logger.clientPrefix = ">>> "
/// logger.serverPrefix = "<<< "
/// ```
///
/// - SeeAlso: ``ProtocolLoggerType``
/// - SeeAlso: ``NullProtocolLogger``
/// - SeeAlso: ``AuthenticationSecretDetector``
public class ProtocolLogger: ProtocolLoggerType {
    /// The default prefix string for client messages.
    ///
    /// This constant value is `"C: "` and is used when creating new `ProtocolLogger`
    /// instances unless a custom prefix is specified.
    public static let defaultClientPrefix = "C: "

    /// The default prefix string for server messages.
    ///
    /// This constant value is `"S: "` and is used when creating new `ProtocolLogger`
    /// instances unless a custom prefix is specified.
    public static let defaultServerPrefix = "S: "

    private static let secretMaskBytes: [UInt8] = Array("********".utf8)
    private static let spaceBytes: [UInt8] = [0x20]

    /// The prefix string to use when logging client messages.
    ///
    /// This string is prepended to each line of data sent by the client.
    /// The default value is ``defaultClientPrefix`` (`"C: "`).
    ///
    /// ## Example
    ///
    /// ```swift
    /// logger.clientPrefix = "CLIENT: "
    /// // Output: CLIENT: EHLO example.com
    /// ```
    public var clientPrefix: String {
        get { String(decoding: clientPrefixBytes, as: UTF8.self) }
        set { clientPrefixBytes = Array(newValue.utf8) }
    }

    /// The prefix string to use when logging server messages.
    ///
    /// This string is prepended to each line of data received from the server.
    /// The default value is ``defaultServerPrefix`` (`"S: "`).
    ///
    /// ## Example
    ///
    /// ```swift
    /// logger.serverPrefix = "SERVER: "
    /// // Output: SERVER: 250 OK
    /// ```
    public var serverPrefix: String {
        get { String(decoding: serverPrefixBytes, as: UTF8.self) }
        set { serverPrefixBytes = Array(newValue.utf8) }
    }

    /// A Boolean value indicating whether authentication secrets should be redacted.
    ///
    /// When `true` (the default), the logger uses the configured
    /// ``authenticationSecretDetector`` to identify secrets in client data and
    /// replaces them with asterisks (`********`) in the log output.
    ///
    /// Set this to `false` to log authentication data unredacted. This is not
    /// recommended for production logs as it may expose sensitive credentials.
    ///
    /// - Important: Secret redaction only works if an ``authenticationSecretDetector``
    ///   is configured. Without a detector, no redaction occurs regardless of this setting.
    public var redactSecrets: Bool = true

    /// A Boolean value indicating whether timestamps should be logged.
    ///
    /// When `true`, each log line is prefixed with a timestamp in the format
    /// specified by ``timestampFormat``. The default value is `false`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// logger.logTimestamps = true
    /// // Output: 2024-01-15T10:30:45Z C: EHLO example.com
    /// ```
    public var logTimestamps: Bool = false

    /// The date and time format string used when logging timestamps.
    ///
    /// This format string is used with `DateFormatter` to format timestamps
    /// when ``logTimestamps`` is `true`. The default format is
    /// `"yyyy-MM-dd'T'HH:mm:ss'Z'"` (ISO 8601 format).
    ///
    /// ## Example
    ///
    /// ```swift
    /// logger.logTimestamps = true
    /// logger.timestampFormat = "HH:mm:ss.SSS"
    /// // Output: 10:30:45.123 C: EHLO example.com
    /// ```
    public var timestampFormat: String = "yyyy-MM-dd'T'HH:mm:ss'Z'"

    /// The authentication secret detector used to identify sensitive data.
    ///
    /// When ``redactSecrets`` is `true` and this property is set, the detector
    /// is used to identify authentication secrets in client data. Detected secrets
    /// are replaced with asterisks in the log output.
    ///
    /// The mail service implementations automatically configure appropriate detectors
    /// for standard authentication mechanisms (LOGIN, PLAIN, OAuth, etc.).
    ///
    /// - SeeAlso: ``AuthenticationSecretDetector``
    public var authenticationSecretDetector: AuthenticationSecretDetector?

    /// The underlying output stream used for writing log data.
    ///
    /// This property provides read-only access to the stream that the logger
    /// writes to. This can be useful for advanced scenarios where you need
    /// to interact with the stream directly.
    public var stream: OutputStream {
        outputStream
    }

    private var clientPrefixBytes: [UInt8]
    private var serverPrefixBytes: [UInt8]
    private let outputStream: OutputStream
    private let leaveOpen: Bool
    private var clientMidline: Bool = false
    private var serverMidline: Bool = false
    private var isClosed: Bool = false

    /// Creates a new `ProtocolLogger` that logs to the specified file URL.
    ///
    /// The file is created if it does not exist. If the file exists and `append`
    /// is `true`, new log data is appended to the existing content.
    ///
    /// - Parameters:
    ///   - fileURL: The URL of the file to log to.
    ///   - append: If `true`, log data is appended to the file; if `false`,
    ///     the file is truncated. The default is `true`.
    ///
    /// - Throws: ``ProtocolLoggerError/unableToOpenStream`` if the file cannot
    ///   be opened for writing.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let logURL = URL(fileURLWithPath: "/tmp/smtp-debug.log")
    /// let logger = try ProtocolLogger(fileURL: logURL)
    /// ```
    public init(fileURL: URL, append: Bool = true) throws {
        guard let stream = OutputStream(url: fileURL, append: append) else {
            throw ProtocolLoggerError.unableToOpenStream
        }
        self.outputStream = stream
        self.leaveOpen = false
        self.clientPrefixBytes = Array(Self.defaultClientPrefix.utf8)
        self.serverPrefixBytes = Array(Self.defaultServerPrefix.utf8)
        stream.open()
        if stream.streamStatus == .error {
            throw ProtocolLoggerError.unableToOpenStream
        }
    }

    /// Creates a new `ProtocolLogger` that logs to the specified file path.
    ///
    /// This is a convenience initializer that converts the file path to a URL
    /// and calls ``init(fileURL:append:)``.
    ///
    /// - Parameters:
    ///   - filePath: The path of the file to log to.
    ///   - append: If `true`, log data is appended to the file; if `false`,
    ///     the file is truncated. The default is `true`.
    ///
    /// - Throws: ``ProtocolLoggerError/unableToOpenStream`` if the file cannot
    ///   be opened for writing.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let logger = try ProtocolLogger(filePath: "/tmp/imap-debug.log")
    /// ```
    public convenience init(filePath: String, append: Bool = true) throws {
        try self.init(fileURL: URL(fileURLWithPath: filePath), append: append)
    }

    /// Creates a new `ProtocolLogger` that logs to the specified output stream.
    ///
    /// Use this initializer when you want to log to a custom destination such as
    /// an in-memory buffer or network stream.
    ///
    /// - Parameters:
    ///   - stream: The output stream to write log data to.
    ///   - leaveOpen: If `true`, the stream is not closed when the logger is closed
    ///     or deallocated. If `false` (the default), the logger takes ownership
    ///     of the stream and closes it when done.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Log to an in-memory buffer
    /// var outputData = Data()
    /// let stream = OutputStream(toMemory: ())
    /// let logger = ProtocolLogger(stream: stream, leaveOpen: false)
    /// ```
    public init(stream: OutputStream, leaveOpen: Bool = false) {
        self.outputStream = stream
        self.leaveOpen = leaveOpen
        self.clientPrefixBytes = Array(Self.defaultClientPrefix.utf8)
        self.serverPrefixBytes = Array(Self.defaultServerPrefix.utf8)
        stream.open()
    }

    deinit {
        close()
    }

    /// Closes the logger and releases any resources.
    ///
    /// After calling this method, the logger should not be used for further logging.
    /// If the logger was initialized with `leaveOpen: false` (the default), the
    /// underlying stream is also closed.
    ///
    /// This method is safe to call multiple times; subsequent calls have no effect.
    ///
    /// - Note: The logger's `deinit` automatically calls `close()`, so explicit
    ///   closing is only necessary if you need to release resources before the
    ///   logger is deallocated.
    public func close() {
        guard !isClosed else { return }
        isClosed = true
        if !leaveOpen {
            outputStream.close()
        }
    }

    /// Logs a connection to the specified URI.
    ///
    /// This method writes a connection message to the log, optionally prefixed
    /// with a timestamp. If there is an incomplete line from a previous log call,
    /// a newline is written first to maintain proper formatting.
    ///
    /// - Parameter uri: The URI of the server being connected to.
    ///
    /// ## Example Output
    ///
    /// Without timestamps:
    /// ```
    /// Connected to imaps://imap.example.com:993/
    /// ```
    ///
    /// With timestamps enabled:
    /// ```
    /// 2024-01-15T10:30:45Z Connected to imaps://imap.example.com:993/
    /// ```
    public func logConnect(_ uri: URL) {
        var message: String
        if logTimestamps {
            message = "\(formattedTimestamp()) Connected to \(uri.absoluteString)\r\n"
        } else {
            message = "Connected to \(uri.absoluteString)\r\n"
        }

        if clientMidline || serverMidline {
            _ = writeBytes([0x0D, 0x0A])
            clientMidline = false
            serverMidline = false
        }

        _ = writeBytes(Array(message.utf8))
    }

    /// Logs a sequence of bytes sent by the client.
    ///
    /// This method is called by the mail service upon every successful write
    /// operation to its underlying network stream, passing the exact buffer,
    /// offset, and count arguments used in the write.
    ///
    /// When ``redactSecrets`` is `true` and an ``authenticationSecretDetector``
    /// is configured, any detected authentication secrets in the buffer are
    /// replaced with asterisks (`********`) in the log output.
    ///
    /// - Parameters:
    ///   - buffer: The buffer containing bytes to log.
    ///   - offset: The zero-based offset of the first byte to log.
    ///   - count: The number of bytes to log.
    ///
    /// - Note: If `offset` is negative or exceeds the buffer length, or if
    ///   `count` is negative or exceeds the available bytes from `offset`,
    ///   the method returns without logging.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let command = Array("EHLO example.com\r\n".utf8)
    /// logger.logClient(command, offset: 0, count: command.count)
    /// // Output: C: EHLO example.com
    /// ```
    public func logClient(_ buffer: [UInt8], offset: Int, count: Int) {
        guard validateArguments(buffer, offset: offset, count: count) else {
            return
        }
        log(prefix: clientPrefixBytes, midline: &clientMidline, buffer: buffer, offset: offset, count: count, isClient: true)
    }

    /// Logs a sequence of bytes sent by the server.
    ///
    /// This method is called by the mail service upon every successful read
    /// of its underlying network stream with the exact buffer that was read.
    ///
    /// - Parameters:
    ///   - buffer: The buffer containing bytes to log.
    ///   - offset: The zero-based offset of the first byte to log.
    ///   - count: The number of bytes to log.
    ///
    /// - Note: If `offset` is negative or exceeds the buffer length, or if
    ///   `count` is negative or exceeds the available bytes from `offset`,
    ///   the method returns without logging.
    ///
    /// - Note: Unlike ``logClient(_:offset:count:)``, server data is never
    ///   redacted since authentication secrets are only present in client messages.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let response = Array("250 OK\r\n".utf8)
    /// logger.logServer(response, offset: 0, count: response.count)
    /// // Output: S: 250 OK
    /// ```
    public func logServer(_ buffer: [UInt8], offset: Int, count: Int) {
        guard validateArguments(buffer, offset: offset, count: count) else {
            return
        }
        log(prefix: serverPrefixBytes, midline: &serverMidline, buffer: buffer, offset: offset, count: count, isClient: false)
    }

    private func validateArguments(_ buffer: [UInt8], offset: Int, count: Int) -> Bool {
        guard offset >= 0, offset <= buffer.count else { return false }
        guard count >= 0, count <= (buffer.count - offset) else { return false }
        return true
    }

    private func log(prefix: [UInt8], midline: inout Bool, buffer: [UInt8], offset: Int, count: Int, isClient: Bool) {
        let endIndex = offset + count
        var index = offset

        while index < endIndex {
            var start = index

            while index < endIndex, buffer[index] != 0x0A {
                index += 1
            }

            if !midline {
                if logTimestamps {
                    let timestampBytes = Array(formattedTimestamp().utf8)
                    _ = writeBytes(timestampBytes)
                    _ = writeBytes(Self.spaceBytes)
                }
                _ = writeBytes(prefix)
            }

            if index < endIndex, buffer[index] == 0x0A {
                midline = false
                index += 1
            } else {
                midline = true
            }

            if isClient, redactSecrets, let detector = authenticationSecretDetector {
                let secrets = detector.detectSecrets(in: buffer, offset: start, count: index - start)
                for secret in secrets {
                    if secret.startIndex > start {
                        _ = writeBytes(Array(buffer[start..<secret.startIndex]))
                    }
                    start = secret.startIndex + secret.length
                    _ = writeBytes(Self.secretMaskBytes)
                }
            }

            if start < index {
                _ = writeBytes(Array(buffer[start..<index]))
            }
        }
    }

    private func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = timestampFormat
        return formatter.string(from: Date())
    }

    @discardableResult
    private func writeBytes(_ bytes: [UInt8]) -> Bool {
        guard !bytes.isEmpty else { return true }
        var totalWritten = 0
        while totalWritten < bytes.count {
            let written = bytes.withUnsafeBytes { pointer -> Int in
                guard let base = pointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return -1
                }
                let start = base.advanced(by: totalWritten)
                return outputStream.write(start, maxLength: bytes.count - totalWritten)
            }

            if written <= 0 {
                return false
            }

            totalWritten += written
        }
        return true
    }
}
