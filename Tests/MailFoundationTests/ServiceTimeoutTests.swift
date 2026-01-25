//
// ServiceTimeoutTests.swift
//
// Tests for service-level timeout functionality.
//

import Foundation
import Testing
@testable import MailFoundation

// MARK: - Timeout Utility Tests

@available(macOS 10.15, iOS 13.0, *)
@Test("withTimeout completes before timeout")
func withTimeoutCompletesBeforeTimeout() async throws {
    let result = try await withTimeout(milliseconds: 1000) {
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        return "success"
    }
    #expect(result == "success")
}

@available(macOS 10.15, iOS 13.0, *)
@Test("withTimeout throws on timeout")
func withTimeoutThrowsOnTimeout() async throws {
    do {
        _ = try await withTimeout(milliseconds: 50) {
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms - will timeout
            return "should not reach"
        }
        Issue.record("Expected timeout error")
    } catch let error as TimeoutError {
        if case let .timedOut(ms) = error {
            #expect(ms == 50)
        } else {
            Issue.record("Expected timedOut error, got \(error)")
        }
    }
}

@available(macOS 10.15, iOS 13.0, *)
@Test("withTimeout propagates operation errors")
func withTimeoutPropagatesOperationErrors() async throws {
    struct TestError: Error {}

    do {
        _ = try await withTimeout(milliseconds: 1000) {
            throw TestError()
        }
        Issue.record("Expected TestError")
    } catch is TestError {
        // Expected
    }
}

@available(macOS 10.15, iOS 13.0, *)
@Test("withTimeout with Int.max does not timeout")
func withTimeoutWithMaxDoesNotTimeout() async throws {
    // Int.max should mean no timeout
    let result = try await withTimeout(milliseconds: Int.max) {
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        return "completed"
    }
    #expect(result == "completed")
}

@available(macOS 10.15, iOS 13.0, *)
@Test("withTimeout seconds overload")
func withTimeoutSecondsOverload() async throws {
    let result = try await withTimeout(seconds: 1) {
        return 42
    }
    #expect(result == 42)
}

@available(macOS 10.15, iOS 13.0, *)
@Test("withTimeout configuration overload")
func withTimeoutConfigurationOverload() async throws {
    let config = ServiceTimeoutConfiguration(timeoutMilliseconds: 1000)
    let result = try await withTimeout(config) {
        return "configured"
    }
    #expect(result == "configured")
}

// MARK: - ServiceTimeoutConfiguration Tests

@Test("ServiceTimeoutConfiguration default values")
func serviceTimeoutConfigurationDefaultValues() {
    let config = ServiceTimeoutConfiguration()
    #expect(config.timeoutMilliseconds == 120_000)
    #expect(config.timeoutSeconds == 120)
}

@Test("ServiceTimeoutConfiguration static configurations")
func serviceTimeoutConfigurationStaticConfigurations() {
    #expect(ServiceTimeoutConfiguration.default.timeoutMilliseconds == 120_000)
    #expect(ServiceTimeoutConfiguration.short.timeoutMilliseconds == 30_000)
    #expect(ServiceTimeoutConfiguration.long.timeoutMilliseconds == 300_000)
    #expect(ServiceTimeoutConfiguration.none.timeoutMilliseconds == Int.max)
}

@Test("ServiceTimeoutConfiguration equality")
func serviceTimeoutConfigurationEquality() {
    let config1 = ServiceTimeoutConfiguration(timeoutMilliseconds: 5000)
    let config2 = ServiceTimeoutConfiguration(timeoutMilliseconds: 5000)
    let config3 = ServiceTimeoutConfiguration(timeoutMilliseconds: 10000)

    #expect(config1 == config2)
    #expect(config1 != config3)
}

// MARK: - Session Timeout Property Tests

@available(macOS 10.15, iOS 13.0, *)
@Test("AsyncImapSession has default timeout")
func asyncImapSessionHasDefaultTimeout() async throws {
    let transport = AsyncStreamTransport()
    let session = AsyncImapSession(transport: transport)

    #expect(await session.timeoutMilliseconds == 120_000)
}

@available(macOS 10.15, iOS 13.0, *)
@Test("AsyncImapSession timeout can be set")
func asyncImapSessionTimeoutCanBeSet() async throws {
    let transport = AsyncStreamTransport()
    let session = AsyncImapSession(transport: transport, timeoutMilliseconds: 30_000)

    #expect(await session.timeoutMilliseconds == 30_000)

    await session.setTimeoutMilliseconds(60_000)
    #expect(await session.timeoutMilliseconds == 60_000)
}

@available(macOS 10.15, iOS 13.0, *)
@Test("AsyncSmtpSession has default timeout")
func asyncSmtpSessionHasDefaultTimeout() async throws {
    let transport = AsyncStreamTransport()
    let session = AsyncSmtpSession(transport: transport)

    #expect(await session.timeoutMilliseconds == 120_000)
}

@available(macOS 10.15, iOS 13.0, *)
@Test("AsyncSmtpSession timeout can be set")
func asyncSmtpSessionTimeoutCanBeSet() async throws {
    let transport = AsyncStreamTransport()
    let session = AsyncSmtpSession(transport: transport, timeoutMilliseconds: 45_000)

    #expect(await session.timeoutMilliseconds == 45_000)

    await session.setTimeoutMilliseconds(90_000)
    #expect(await session.timeoutMilliseconds == 90_000)
}

@available(macOS 10.15, iOS 13.0, *)
@Test("AsyncPop3Session has default timeout")
func asyncPop3SessionHasDefaultTimeout() async throws {
    let transport = AsyncStreamTransport()
    let session = AsyncPop3Session(transport: transport)

    #expect(await session.timeoutMilliseconds == 120_000)
}

@available(macOS 10.15, iOS 13.0, *)
@Test("AsyncPop3Session timeout can be set")
func asyncPop3SessionTimeoutCanBeSet() async throws {
    let transport = AsyncStreamTransport()
    let session = AsyncPop3Session(transport: transport, timeoutMilliseconds: 15_000)

    #expect(await session.timeoutMilliseconds == 15_000)

    await session.setTimeoutMilliseconds(30_000)
    #expect(await session.timeoutMilliseconds == 30_000)
}

// MARK: - Store Timeout Property Tests

@available(macOS 10.15, iOS 13.0, *)
@Test("AsyncImapMailStore has default timeout")
func asyncImapMailStoreHasDefaultTimeout() async throws {
    let transport = AsyncStreamTransport()
    let store = AsyncImapMailStore(transport: transport)

    #expect(await store.timeoutMilliseconds == 120_000)
}

@available(macOS 10.15, iOS 13.0, *)
@Test("AsyncImapMailStore timeout can be set")
func asyncImapMailStoreTimeoutCanBeSet() async throws {
    let transport = AsyncStreamTransport()
    let store = AsyncImapMailStore(transport: transport, timeoutMilliseconds: 60_000)

    #expect(await store.timeoutMilliseconds == 60_000)

    await store.setTimeout(milliseconds: 90_000)
    #expect(await store.timeoutMilliseconds == 90_000)
}

@available(macOS 10.15, iOS 13.0, *)
@Test("AsyncSmtpTransport has default timeout")
func asyncSmtpTransportHasDefaultTimeout() async throws {
    let transport = AsyncStreamTransport()
    let smtp = AsyncSmtpTransport(transport: transport)

    #expect(await smtp.timeoutMilliseconds == 120_000)
}

@available(macOS 10.15, iOS 13.0, *)
@Test("AsyncSmtpTransport timeout can be set")
func asyncSmtpTransportTimeoutCanBeSet() async throws {
    let transport = AsyncStreamTransport()
    let smtp = AsyncSmtpTransport(transport: transport, timeoutMilliseconds: 45_000)

    #expect(await smtp.timeoutMilliseconds == 45_000)

    await smtp.setTimeout(milliseconds: 120_000)
    #expect(await smtp.timeoutMilliseconds == 120_000)
}

@available(macOS 10.15, iOS 13.0, *)
@Test("AsyncPop3MailStore has default timeout")
func asyncPop3MailStoreHasDefaultTimeout() async throws {
    let transport = AsyncStreamTransport()
    let store = AsyncPop3MailStore(transport: transport)

    #expect(await store.timeoutMilliseconds == 120_000)
}

@available(macOS 10.15, iOS 13.0, *)
@Test("AsyncPop3MailStore timeout can be set")
func asyncPop3MailStoreTimeoutCanBeSet() async throws {
    let transport = AsyncStreamTransport()
    let store = AsyncPop3MailStore(transport: transport, timeoutMilliseconds: 30_000)

    #expect(await store.timeoutMilliseconds == 30_000)

    await store.setTimeout(milliseconds: 60_000)
    #expect(await store.timeoutMilliseconds == 60_000)
}

// MARK: - Default Timeout Constants Tests

@Test("Default timeout constants match MailKit")
func defaultTimeoutConstantsMatchMailKit() {
    // MailKit uses 2 minutes (120 seconds = 120,000 ms) as default
    #expect(defaultImapTimeoutMs == 120_000)
    #expect(defaultSmtpTimeoutMs == 120_000)
    #expect(defaultPop3TimeoutMs == 120_000)
    #expect(defaultServiceTimeoutMs == 120_000)
}

// MARK: - Duration API Tests (macOS 13+/iOS 16+)

@available(macOS 13.0, iOS 16.0, *)
@Test("ServiceTimeoutConfiguration Duration init")
func serviceTimeoutConfigurationDurationInit() {
    let config = ServiceTimeoutConfiguration(timeout: .seconds(30))
    #expect(config.timeoutMilliseconds == 30_000)

    let config2 = ServiceTimeoutConfiguration(timeout: .milliseconds(500))
    #expect(config2.timeoutMilliseconds == 500)
}

@available(macOS 13.0, iOS 16.0, *)
@Test("ServiceTimeoutConfiguration timeout property")
func serviceTimeoutConfigurationTimeoutProperty() {
    let config = ServiceTimeoutConfiguration(timeoutMilliseconds: 5000)
    #expect(config.timeout == .milliseconds(5000))
}

@available(macOS 13.0, iOS 16.0, *)
@Test("TimeoutError duration property")
func timeoutErrorDurationProperty() {
    let error = TimeoutError.timedOut(milliseconds: 1000)
    #expect(error.duration == .milliseconds(1000))

    let cancelledError = TimeoutError.cancelled
    #expect(cancelledError.duration == nil)
}

@available(macOS 13.0, iOS 16.0, *)
@Test("withTimeout Duration overload")
func withTimeoutDurationOverload() async throws {
    let result = try await withTimeout(.seconds(1)) {
        return "duration-based"
    }
    #expect(result == "duration-based")
}
