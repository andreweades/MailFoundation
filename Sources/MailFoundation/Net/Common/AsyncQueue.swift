//
// AsyncQueue.swift
//
// Simple async queue.
//

@available(macOS 10.15, iOS 13.0, *)
public actor AsyncQueue<Element: Sendable> {
    private var elements: [Element] = []
    private var waiters: [CheckedContinuation<Element?, Never>] = []
    private var finished = false

    public init() {}

    public func enqueue(_ element: Element) {
        guard !finished else { return }
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.resume(returning: element)
        } else {
            elements.append(element)
        }
    }

    public func dequeue() async -> Element? {
        if !elements.isEmpty {
            return elements.removeFirst()
        }
        if finished {
            return nil
        }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    public func finish() {
        guard !finished else { return }
        finished = true
        let pending = waiters
        waiters.removeAll(keepingCapacity: true)
        for waiter in pending {
            waiter.resume(returning: nil)
        }
    }
}
