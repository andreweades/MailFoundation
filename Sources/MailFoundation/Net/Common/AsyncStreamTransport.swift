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
