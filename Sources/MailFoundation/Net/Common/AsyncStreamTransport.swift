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
// AsyncStreamTransport.swift
//
// AsyncStream-backed transport for embedded/non-network use.
//

@available(macOS 10.15, iOS 13.0, *)
public actor AsyncStreamTransport: AsyncTransport {
    public nonisolated let incoming: AsyncStream<[UInt8]>
    private let continuation: AsyncStream<[UInt8]>.Continuation
    private var started: Bool = false
    private var sent: [[UInt8]] = []
    private let sendHandler: (@Sendable ([UInt8]) async throws -> Void)?

    public init(sendHandler: (@Sendable ([UInt8]) async throws -> Void)? = nil) {
        var continuation: AsyncStream<[UInt8]>.Continuation!
        self.incoming = AsyncStream { cont in
            continuation = cont
        }
        self.continuation = continuation
        self.sendHandler = sendHandler
    }

    public func start() async throws {
        started = true
    }

    public func stop() async {
        started = false
        continuation.finish()
    }

    public func send(_ bytes: [UInt8]) async throws {
        guard started else {
            throw AsyncTransportError.notStarted
        }
        if let handler = sendHandler {
            try await handler(bytes)
        } else {
            sent.append(bytes)
        }
    }

    public func yieldIncoming(_ bytes: [UInt8]) {
        continuation.yield(bytes)
    }

    public func sentSnapshot() -> [[UInt8]] {
        sent
    }
}
