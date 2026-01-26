//
// ServiceTimeout.swift
//
// Service-level timeout configuration and utilities (ported from MailKit patterns).
//

import Foundation

// MARK: - Default Timeout

/// Default timeout value for mail service operations in milliseconds.
///
/// The default value is 120,000 milliseconds (2 minutes), matching MailKit's
/// default timeout behavior. This value is used when no explicit timeout
/// is specified for mail service operations.
///
/// - Note: Ported from MailKit's `Timeout` property default value.
public let defaultServiceTimeoutMs: Int = 120_000

// MARK: - Service Timeout Configuration

/// Configuration for timeout behavior in mail service operations.
///
/// `ServiceTimeoutConfiguration` provides a consistent way to configure
/// timeouts across mail services. It mirrors MailKit's timeout behavior
/// where a single timeout value applies to all network streaming operations.
///
/// ## Preset Configurations
///
/// Several preset configurations are available:
/// - ``default``: 2 minutes (recommended for most operations)
/// - ``short``: 30 seconds (quick operations, connection checks)
/// - ``long``: 5 minutes (large attachments, slow connections)
/// - ``none``: No timeout (use with caution)
///
/// ## Example Usage
///
/// ```swift
/// // Using a preset
/// let config = ServiceTimeoutConfiguration.short
///
/// // Custom timeout
/// let customConfig = ServiceTimeoutConfiguration(timeoutMilliseconds: 45_000)
///
/// // With async operations
/// let result = try await withTimeout(config) {
///     try await someAsyncOperation()
/// }
/// ```
///
/// - Note: Ported from MailKit's `Timeout` property pattern.
public struct ServiceTimeoutConfiguration: Sendable, Equatable {
    /// The timeout duration in milliseconds for network operations.
    ///
    /// This value is applied to read and write operations on the
    /// network stream.
    public var timeoutMilliseconds: Int

    /// Creates a timeout configuration with the specified duration.
    ///
    /// - Parameter timeoutMilliseconds: The timeout in milliseconds
    ///   (default: 120,000 = 2 minutes).
    public init(timeoutMilliseconds: Int = defaultServiceTimeoutMs) {
        self.timeoutMilliseconds = timeoutMilliseconds
    }

    /// A configuration with no timeout (infinite wait).
    ///
    /// - Warning: Use with caution as operations may hang indefinitely.
    public static let none = ServiceTimeoutConfiguration(timeoutMilliseconds: Int.max)

    /// The default configuration (2 minutes).
    ///
    /// This is appropriate for most mail operations including
    /// authentication, sending messages, and folder operations.
    public static let `default` = ServiceTimeoutConfiguration()

    /// A short timeout configuration (30 seconds).
    ///
    /// Useful for quick operations like connection testing or
    /// simple commands where fast failure is preferred.
    public static let short = ServiceTimeoutConfiguration(timeoutMilliseconds: 30_000)

    /// A long timeout configuration (5 minutes).
    ///
    /// Useful for operations involving large data transfers or
    /// connections over slow networks.
    public static let long = ServiceTimeoutConfiguration(timeoutMilliseconds: 300_000)

    /// The timeout duration in seconds.
    ///
    /// Convenience property for APIs that expect seconds rather
    /// than milliseconds.
    public var timeoutSeconds: Int {
        timeoutMilliseconds / 1000
    }
}

// MARK: - Timeout Error

/// Errors that can occur during timeout-wrapped operations.
///
/// These errors are thrown by the `withTimeout` family of functions
/// when operations exceed their allowed duration or are cancelled.
public enum TimeoutError: Error, Sendable {
    /// The operation exceeded its timeout duration.
    ///
    /// - Parameter milliseconds: The timeout duration that was exceeded.
    case timedOut(milliseconds: Int)

    /// The operation was cancelled before completion.
    ///
    /// This typically occurs when the parent task is cancelled.
    case cancelled
}

// MARK: - Timeout Functions

/// Executes an async operation with a timeout in milliseconds.
///
/// This function wraps an async operation and throws ``TimeoutError/timedOut(milliseconds:)``
/// if the operation does not complete within the specified duration.
///
/// ## Implementation Details
///
/// The function uses a task group with two competing tasks:
/// 1. The actual operation
/// 2. A sleep task that throws on timeout
///
/// Whichever completes first wins, and the other is cancelled.
///
/// ## Example Usage
///
/// ```swift
/// do {
///     let result = try await withTimeout(milliseconds: 5000) {
///         try await fetchData()
///     }
///     print("Got result: \(result)")
/// } catch let error as TimeoutError {
///     print("Operation timed out")
/// }
/// ```
///
/// - Parameters:
///   - milliseconds: The maximum time to wait in milliseconds.
///   - operation: The async operation to execute.
/// - Returns: The result of the operation if it completes in time.
/// - Throws: ``TimeoutError/timedOut(milliseconds:)`` if the operation exceeds
///   the timeout, or any error thrown by the operation itself.
///
/// - Note: Available on macOS 10.15+ and iOS 13.0+.
@available(macOS 10.15, iOS 13.0, *)
public func withTimeout<T: Sendable>(
    milliseconds: Int,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    guard milliseconds < Int.max else {
        // No timeout
        return try await operation()
    }

    return try await withThrowingTaskGroup(of: T.self) { group in
        // Add the main operation
        group.addTask {
            try await operation()
        }

        // Add a timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
            throw TimeoutError.timedOut(milliseconds: milliseconds)
        }

        // Return the first result (either success or timeout)
        guard let result = try await group.next() else {
            throw TimeoutError.cancelled
        }

        // Cancel the remaining task
        group.cancelAll()

        return result
    }
}

/// Executes an async operation with a timeout in seconds.
///
/// - Parameters:
///   - seconds: The maximum time to wait in seconds
///   - operation: The async operation to execute
/// - Returns: The result of the operation
/// - Throws: `TimeoutError.timedOut` if the operation exceeds the timeout
@available(macOS 10.15, iOS 13.0, *)
public func withTimeout<T: Sendable>(
    seconds: Int,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withTimeout(milliseconds: seconds * 1000, operation: operation)
}

/// Executes an async operation with a timeout configuration.
///
/// - Parameters:
///   - configuration: The timeout configuration
///   - operation: The async operation to execute
/// - Returns: The result of the operation
/// - Throws: `TimeoutError.timedOut` if the operation exceeds the timeout
@available(macOS 10.15, iOS 13.0, *)
public func withTimeout<T: Sendable>(
    _ configuration: ServiceTimeoutConfiguration,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withTimeout(milliseconds: configuration.timeoutMilliseconds, operation: operation)
}

// MARK: - Duration-based API (macOS 13+/iOS 16+)

@available(macOS 13.0, iOS 16.0, *)
public extension ServiceTimeoutConfiguration {
    /// Creates a timeout configuration with the specified Duration.
    init(timeout: Duration) {
        let components = timeout.components
        self.timeoutMilliseconds = Int(components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000)
    }

    /// The timeout as a Duration.
    var timeout: Duration {
        .milliseconds(timeoutMilliseconds)
    }
}

@available(macOS 13.0, iOS 16.0, *)
public extension TimeoutError {
    /// The timeout duration (for `.timedOut` case).
    var duration: Duration? {
        switch self {
        case let .timedOut(milliseconds):
            return .milliseconds(milliseconds)
        case .cancelled:
            return nil
        }
    }
}

/// Executes an async operation with a Duration timeout.
///
/// - Parameters:
///   - timeout: The maximum Duration to wait
///   - operation: The async operation to execute
/// - Returns: The result of the operation
/// - Throws: `TimeoutError.timedOut` if the operation exceeds the timeout
@available(macOS 13.0, iOS 16.0, *)
public func withTimeout<T: Sendable>(
    _ timeout: Duration,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    let config = ServiceTimeoutConfiguration(timeout: timeout)
    return try await withTimeout(milliseconds: config.timeoutMilliseconds, operation: operation)
}
