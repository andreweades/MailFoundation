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

import Testing
@testable import MailFoundation

private enum StartTlsTestError: Error, Equatable {
    case failed
}

@available(macOS 10.15, iOS 13.0, *)
@Test("Async SMTP session STARTTLS failure propagation")
func asyncSmtpSessionStartTlsFailure() async throws {
    let transport = FailingStartTlsAsyncTransport()
    let session = AsyncSmtpSession(transport: transport)

    let connectTask = Task { try await session.connect() }
    await transport.yieldIncoming(Array("220 Ready\r\n".utf8))
    _ = try await connectTask.value

    let startTlsTask = Task { try await session.startTls(validateCertificate: true) }
    await transport.yieldIncoming(Array("220 Go ahead\r\n".utf8))

    do {
        _ = try await startTlsTask.value
        #expect(Bool(false))
    } catch let error as StartTlsTestError {
        #expect(error == .failed)
    }
}

@available(macOS 10.15, iOS 13.0, *)
@Test("Async POP3 session STARTTLS failure propagation")
func asyncPop3SessionStartTlsFailure() async throws {
    let transport = FailingStartTlsAsyncTransport()
    let session = AsyncPop3Session(transport: transport)

    let connectTask = Task { try await session.connect() }
    await transport.yieldIncoming(Array("+OK Ready\r\n".utf8))
    _ = try await connectTask.value

    let startTlsTask = Task { try await session.startTls(validateCertificate: true) }
    await transport.yieldIncoming(Array("+OK Begin TLS\r\n".utf8))

    do {
        _ = try await startTlsTask.value
        #expect(Bool(false))
    } catch let error as StartTlsTestError {
        #expect(error == .failed)
    }
}

@available(macOS 10.15, iOS 13.0, *)
@Test("Async IMAP session STARTTLS failure propagation")
func asyncImapSessionStartTlsFailure() async throws {
    let transport = FailingStartTlsAsyncTransport()
    let session = AsyncImapSession(transport: transport)

    let connectTask = Task { try await session.connect() }
    await transport.yieldIncoming(Array("* OK Ready\r\n".utf8))
    _ = try await connectTask.value

    let startTlsTask = Task { try await session.startTls(validateCertificate: true) }
    await transport.yieldIncoming(Array("A0001 OK Begin TLS\r\n".utf8))

    do {
        _ = try await startTlsTask.value
        #expect(Bool(false))
    } catch let error as StartTlsTestError {
        #expect(error == .failed)
    }
}

@available(macOS 10.15, iOS 13.0, *)
private actor FailingStartTlsAsyncTransport: AsyncStartTlsTransport {
    public nonisolated let incoming: AsyncStream<[UInt8]>
    private let continuation: AsyncStream<[UInt8]>.Continuation
    private var started = false
    var scramChannelBinding: ScramChannelBinding? { get async { nil } }

    init() {
        var continuation: AsyncStream<[UInt8]>.Continuation!
        self.incoming = AsyncStream { cont in
            continuation = cont
        }
        self.continuation = continuation
    }

    func start() async throws {
        started = true
    }

    func stop() async {
        started = false
        continuation.finish()
    }

    func send(_ bytes: [UInt8]) async throws {
        guard started else {
            throw AsyncTransportError.notStarted
        }
    }

    func startTLS(validateCertificate: Bool) async throws {
        guard started else {
            throw AsyncTransportError.notStarted
        }
        throw StartTlsTestError.failed
    }

    func yieldIncoming(_ bytes: [UInt8]) {
        continuation.yield(bytes)
    }
}
