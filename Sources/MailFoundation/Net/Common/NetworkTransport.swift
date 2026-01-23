//
// NetworkTransport.swift
//
// Network.framework transport (iOS/macOS).
//

#if canImport(Network)
@preconcurrency import Network
import Foundation
#if canImport(Security)
import Security
#endif

@available(macOS 10.15, iOS 13.0, *)
public actor NetworkTransport: AsyncStartTlsTransport {
    public nonisolated let incoming: AsyncStream<[UInt8]>
    private let continuation: AsyncStream<[UInt8]>.Continuation
    private var connection: NWConnection
    private let queue: DispatchQueue
    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    private let hostString: String
    private var started: Bool = false

    public init(host: String, port: UInt16, parameters: NWParameters = .tcp) {
        var continuation: AsyncStream<[UInt8]>.Continuation!
        self.incoming = AsyncStream { cont in
            continuation = cont
        }
        self.continuation = continuation
        self.queue = DispatchQueue(label: "mailfoundation.networktransport")
        self.hostString = host
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(rawValue: port)!
        self.connection = NWConnection(host: self.host, port: self.port, using: parameters)
    }

    public func start() async throws {
        guard !started else { return }
        started = true
        connection.start(queue: queue)
        receiveLoop(for: connection)
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

    public func startTLS(validateCertificate: Bool) async throws {
        guard started else {
            throw AsyncTransportError.notStarted
        }

        let tlsParameters = makeTlsParameters(validateCertificate: validateCertificate)
        let newConnection = NWConnection(host: host, port: port, using: tlsParameters)
        let oldConnection = connection
        connection = newConnection
        oldConnection.cancel()
        newConnection.start(queue: queue)
        receiveLoop(for: newConnection)
    }

    private func receiveLoop(for connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] content, _, isComplete, error in
            guard let self else { return }
            Task { await self.handleReceive(content: content, isComplete: isComplete, error: error, connection: connection) }
        }
    }

    private func handleReceive(content: Data?, isComplete: Bool, error: NWError?, connection: NWConnection) async {
        guard connection === self.connection else { return }
        if let content, !content.isEmpty {
            continuation.yield([UInt8](content))
        }

        if error != nil || isComplete {
            await stop()
            return
        }

        receiveLoop(for: connection)
    }

    private func makeTlsParameters(validateCertificate: Bool) -> NWParameters {
        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, hostString)
        if !validateCertificate {
            #if canImport(Security)
            sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { _, _, completion in
                completion(true)
            }, queue)
            #endif
        }
        let tcpOptions = NWProtocolTCP.Options()
        return NWParameters(tls: tlsOptions, tcp: tcpOptions)
    }
}
#endif
