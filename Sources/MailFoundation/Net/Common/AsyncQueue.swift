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
