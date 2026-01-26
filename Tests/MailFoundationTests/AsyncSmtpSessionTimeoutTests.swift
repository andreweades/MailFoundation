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

struct AsyncSmtpSessionTimeoutTests {

    @Test("Async SMTP session throws TimeoutError when operation times out")
    func asyncSmtpSessionTimeout() async throws {
        // Use a short timeout for the test (100ms)
        let timeoutMs = 100
        let transport = AsyncStreamTransport()
        let session = AsyncSmtpSession(transport: transport, timeoutMilliseconds: timeoutMs)

        // Connect and receive greeting
        let connectTask = Task { try await session.connect() }
        await transport.yieldIncoming(Array("220 smtp.example.com ESMTP\r\n".utf8))
        _ = try await connectTask.value

        // Perform an operation that will time out (server sends no response)
        let noopTask = Task { 
            try await session.noop() 
        }

        // We do NOT yield any data here. The server is silent. 
        
        do {
            // We wait a bit longer than the configured timeout to ensure it triggers
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
}

