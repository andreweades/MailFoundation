//
// NetworkTransport.swift
//
// Network.framework transport (iOS/macOS).
//

#if canImport(Network)
@preconcurrency import Network
import Foundation

@available(macOS 10.15, iOS 13.0, *)
public actor NetworkTransport: AsyncTransport {
    public nonisolated let incoming: AsyncStream<[UInt8]>
    private let continuation: AsyncStream<[UInt8]>.Continuation
    private let connection: NWConnection
    private let queue: DispatchQueue
    private var started: Bool = false

    public init(host: String, port: UInt16, parameters: NWParameters = .tcp) {
        var continuation: AsyncStream<[UInt8]>.Continuation!
        self.incoming = AsyncStream { cont in
            continuation = cont
        }
        self.continuation = continuation
        self.queue = DispatchQueue(label: "mailfoundation.networktransport")
        self.connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: parameters)
    }

    public func start() async throws {
        guard !started else { return }
        started = true
        connection.start(queue: queue)
        receiveLoop()
    }

    public func stop() async {
        guard started else { return }
        started = false
        connection.cancel()
        continuation.finish()
    }

    public func send(_ bytes: [UInt8]) async throws {
        guard started else {
            throw AsyncTransportError.notStarted
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: bytes, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func receiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] content, _, isComplete, error in
            guard let self else { return }
            Task { await self.handleReceive(content: content, isComplete: isComplete, error: error) }
        }
    }

    private func handleReceive(content: Data?, isComplete: Bool, error: NWError?) async {
        if let content, !content.isEmpty {
            continuation.yield([UInt8](content))
        }

        if error != nil || isComplete {
            await stop()
            return
        }

        receiveLoop()
    }
}
#endif
