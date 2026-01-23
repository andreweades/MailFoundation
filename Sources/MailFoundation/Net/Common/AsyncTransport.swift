//
// AsyncTransport.swift
//
// Async transport abstraction.
//

@available(macOS 10.15, iOS 13.0, *)
public protocol AsyncTransport: AnyObject, Sendable {
    var incoming: AsyncStream<[UInt8]> { get }
    func start() async throws
    func stop() async
    func send(_ bytes: [UInt8]) async throws
}

public enum AsyncTransportError: Error, Sendable {
    case notStarted
    case sendFailed
    case receiveFailed
    case connectionFailed
}
