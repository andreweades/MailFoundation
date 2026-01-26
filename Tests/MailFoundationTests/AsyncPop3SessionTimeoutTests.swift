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
import Foundation
@testable import MailFoundation

struct AsyncPop3SessionTimeoutTests {

    @Test("Async POP3 session throws TimeoutError when operation times out")
    func asyncPop3SessionTimeout() async throws {
        // Use a short timeout for the test (100ms)
        let timeoutMs = 100
        let transport = AsyncStreamTransport()
        let session = AsyncPop3Session(transport: transport, timeoutMilliseconds: timeoutMs)

        // Connect
        let connectTask = Task { try await session.connect() }
        await transport.yieldIncoming(Array("+OK POP3 server ready\r\n".utf8))
        _ = try await connectTask.value

        // Authenticate (fake it)
        // We can't easily fake the full auth flow without complex yields if we use .authenticate().
        // But we can use USER/PASS commands directly if we yield appropriate responses.
        // Or we can just mock the state if we had access, but we don't.
        // Let's use authenticate(user, password)
        let authTask = Task { try await session.authenticate(user: "user", password: "pass") }
        await transport.yieldIncoming(Array("+OK User accepted\r\n".utf8))
        await transport.yieldIncoming(Array("+OK Pass accepted\r\n".utf8))
        _ = try await authTask.value

        // Perform an operation that will time out (server sends no response)
        let noopTask = Task { 
            try await session.noop() 
        }

        // We do NOT yield any data here. The server is silent.
        
        do {
            try await withTimeout(milliseconds: 500) {
                _ = try await noopTask.value
            }
            #expect(Bool(false), "Should have thrown a timeout error")
        } catch let error as SessionError {
             if case .timeout = error {
                 // Success: SessionError.timeout
             } else {
                 #expect(Bool(false), "Unexpected error type: \(error)")
             }
        } catch let error as TimeoutError {
            if case .timedOut = error {
                 // Success: TimeoutError.timedOut
            } else {
                 #expect(Bool(false), "Unexpected error type: \(error)")
            }
        } catch {
             #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("Async POP3 session handles unexpected connection drop during command")
    func asyncPop3ConnectionDrop() async throws {
        let transport = AsyncStreamTransport()
        let session = AsyncPop3Session(transport: transport, timeoutMilliseconds: 500)

        // Connect
        let connectTask = Task { try await session.connect() }
        await transport.yieldIncoming(Array("+OK POP3 server ready\r\n".utf8))
        _ = try await connectTask.value

        // Authenticate
        let authTask = Task { try await session.authenticate(user: "user", password: "pass") }
        await transport.yieldIncoming(Array("+OK User accepted\r\n".utf8))
        await transport.yieldIncoming(Array("+OK Pass accepted\r\n".utf8))
        _ = try await authTask.value

        // Start a command
        let noopTask = Task { 
            try await session.noop() 
        }
        
        try await Task.sleep(nanoseconds: 10_000_000)
        
        // Simulate connection drop
        await transport.stop()
        
        do {
            _ = try await noopTask.value
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as SessionError {
            if case .connectionClosed(let message) = error {
                #expect(message == "Connection closed by server.")
            } else {
                #expect(Bool(false), "Unexpected error type: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }
}
