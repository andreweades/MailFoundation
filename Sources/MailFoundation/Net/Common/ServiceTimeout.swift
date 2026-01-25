//
// ServiceTimeout.swift
//
// Service-level timeout configuration and utilities (ported from MailKit patterns).
//

import Foundation

/// Default timeout value for mail service operations in milliseconds (2 minutes, matching MailKit).
public let defaultServiceTimeoutMs: Int = 120_000

/// Timeout configuration for mail service operations.
///
/// This mirrors MailKit's timeout behavior where a single timeout value
/// applies to all network streaming operations (read/write).
public struct ServiceTimeoutConfiguration: Sendable, Equatable {
    /// The timeout in milliseconds for network operations.
    public var timeoutMilliseconds: Int

    /// Creates a timeout configuration with the specified duration in milliseconds.
    ///
    /// - Parameter timeoutMilliseconds: The timeout in milliseconds (default: 120000 = 2 minutes)
    public init(timeoutMilliseconds: Int = defaultServiceTimeoutMs) {
        self.timeoutMilliseconds = timeoutMilliseconds
    }

    /// A configuration with no timeout (infinite wait).
    public static let none = ServiceTimeoutConfiguration(timeoutMilliseconds: Int.max)

    /// The default configuration (2 minutes).
    public static let `default` = ServiceTimeoutConfiguration()

    /// A short timeout configuration (30 seconds).
    public static let short = ServiceTimeoutConfiguration(timeoutMilliseconds: 30_000)

    /// A long timeout configuration (5 minutes).
    public static let long = ServiceTimeoutConfiguration(timeoutMilliseconds: 300_000)

    /// The timeout in seconds.
    public var timeoutSeconds: Int {
        timeoutMilliseconds / 1000
    }
}

/// Errors that can occur during timeout operations.
public enum TimeoutError: Error, Sendable {
    /// The operation timed out after the specified milliseconds.
    case timedOut(milliseconds: Int)

    /// The operation was cancelled.
    case cancelled
}

/// Executes an async operation with a timeout in milliseconds.
///
/// This utility wraps an async operation and throws `TimeoutError.timedOut`
/// if the operation does not complete within the specified duration.
///
/// - Parameters:
///   - milliseconds: The maximum time to wait in milliseconds
///   - operation: The async operation to execute
/// - Returns: The result of the operation
/// - Throws: `TimeoutError.timedOut` if the operation exceeds the timeout,
///           or any error thrown by the operation itself
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
