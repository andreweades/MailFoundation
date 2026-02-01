//
// MailFoundationLogger.swift
//
// Logging infrastructure for MailFoundation.
//

import Foundation

/// Log levels for MailFoundation logging.
public enum MailFoundationLogLevel: Int, Sendable, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    public static func < (lhs: MailFoundationLogLevel, rhs: MailFoundationLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Categories for MailFoundation log messages.
public enum MailFoundationLogCategory: String, Sendable {
    case imapClient = "ImapClient"
    case imapSession = "ImapSession"
    case imapDecoder = "ImapDecoder"
    case imapFetch = "ImapFetch"
    case general = "General"
}

/// Protocol for receiving log messages from MailFoundation.
///
/// Implement this protocol to receive log messages from MailFoundation components.
/// You can then route these messages to your preferred logging system (os.Logger,
/// file logging, console, etc.).
///
/// ## Example
///
/// ```swift
/// class MyLogger: MailFoundationLoggerProtocol {
///     func log(level: MailFoundationLogLevel,
///              category: MailFoundationLogCategory,
///              message: String) {
///         print("[\(category.rawValue)] \(message)")
///     }
/// }
///
/// // Configure MailFoundation to use your logger
/// MailFoundationLogging.logger = MyLogger()
/// ```
public protocol MailFoundationLoggerProtocol: Sendable {
    /// Logs a message with the specified level and category.
    ///
    /// - Parameters:
    ///   - level: The severity level of the message.
    ///   - category: The component category that generated the message.
    ///   - message: The log message.
    func log(level: MailFoundationLogLevel, category: MailFoundationLogCategory, message: String)
}

/// Global logging configuration for MailFoundation.
///
/// Use this class to configure logging for all MailFoundation components.
///
/// ## Example
///
/// ```swift
/// // Set a custom logger
/// MailFoundationLogging.logger = MyCustomLogger()
///
/// // Or disable logging
/// MailFoundationLogging.logger = nil
/// ```
public final class MailFoundationLogging: @unchecked Sendable {
    private static let lock = NSLock()
    // Protected by lock - using nonisolated(unsafe) to acknowledge external synchronization
    nonisolated(unsafe) private static var _logger: MailFoundationLoggerProtocol?

    /// The logger instance used by MailFoundation.
    ///
    /// Set this to your own logger implementation to receive log messages.
    /// Set to `nil` to disable logging (the default).
    public static var logger: MailFoundationLoggerProtocol? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _logger
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _logger = newValue
        }
    }

    /// Logs a message if a logger is configured.
    internal static func log(
        level: MailFoundationLogLevel,
        category: MailFoundationLogCategory,
        message: @autoclosure () -> String
    ) {
        lock.lock()
        let currentLogger = _logger
        lock.unlock()

        if let currentLogger {
            currentLogger.log(level: level, category: category, message: message())
        }
    }

    /// Convenience method for debug-level logging.
    internal static func debug(_ category: MailFoundationLogCategory, _ message: @autoclosure () -> String) {
        log(level: .debug, category: category, message: message())
    }

    /// Convenience method for info-level logging.
    internal static func info(_ category: MailFoundationLogCategory, _ message: @autoclosure () -> String) {
        log(level: .info, category: category, message: message())
    }

    /// Convenience method for warning-level logging.
    internal static func warning(_ category: MailFoundationLogCategory, _ message: @autoclosure () -> String) {
        log(level: .warning, category: category, message: message())
    }

    /// Convenience method for error-level logging.
    internal static func error(_ category: MailFoundationLogCategory, _ message: @autoclosure () -> String) {
        log(level: .error, category: category, message: message())
    }
}
