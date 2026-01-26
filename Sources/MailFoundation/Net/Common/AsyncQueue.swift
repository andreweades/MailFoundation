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
// AsyncQueue.swift
//
// Simple async queue with cancellation support.
//

import Foundation

private final class QueueState<Element: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    var elements: [Element] = []
    var waiters: [CheckedContinuation<Element?, Never>] = []
    var finished = false

    func enqueue(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !finished else { return }
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.resume(returning: element)
        } else {
            elements.append(element)
        }
    }

    func dequeue(continuation: CheckedContinuation<Element?, Never>) {
        lock.lock()
        defer { lock.unlock() }
        
        if !elements.isEmpty {
            continuation.resume(returning: elements.removeFirst())
        } else if finished {
            continuation.resume(returning: nil)
        } else {
            waiters.append(continuation)
        }
    }

    func cancelAll() {
        lock.lock()
        let pending = waiters
        waiters.removeAll()
        lock.unlock()
        
        for waiter in pending {
            waiter.resume(returning: nil)
        }
    }

    func finish() {
        lock.lock()
        finished = true
        let pending = waiters
        waiters.removeAll()
        lock.unlock()
        
        for waiter in pending {
            waiter.resume(returning: nil)
        }
    }
}

@available(macOS 10.15, iOS 13.0, *)
public actor AsyncQueue<Element: Sendable> {
    private let state = QueueState<Element>()

    public init() {}

    public func enqueue(_ element: Element) {
        state.enqueue(element)
    }

    public func dequeue() async -> Element? {
        if Task.isCancelled { return nil }
        
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                state.dequeue(continuation: continuation)
            }
        } onCancel: {
            state.cancelAll()
        }
    }

    public func finish() {
        state.finish()
    }
}
