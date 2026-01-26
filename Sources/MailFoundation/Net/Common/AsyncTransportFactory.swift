//
// AsyncTransportFactory.swift
//
// Async transport factory helpers.
//

public enum AsyncTransportBackend: Sendable {
    case network
    case socket
    case asyncStream
    case openssl
}

public enum AsyncTransportFactoryError: Error, Sendable {
    case backendUnavailable
}

@available(macOS 10.15, iOS 13.0, *)
public enum AsyncTransportFactory {
    public static func make(host: String, port: UInt16, backend: AsyncTransportBackend) throws -> AsyncTransport {
        switch backend {
        case .network:
            #if canImport(Network)
            return NetworkTransport(host: host, port: port)
            #else
            throw AsyncTransportFactoryError.backendUnavailable
            #endif
        case .socket:
            #if !os(iOS)
            return SocketTransport(host: host, port: port)
            #else
            throw AsyncTransportFactoryError.backendUnavailable
            #endif
        case .asyncStream:
            return AsyncStreamTransport()
        case .openssl:
            #if canImport(COpenSSL)
            return OpenSSLTransport(host: host, port: port)
            #else
            throw AsyncTransportFactoryError.backendUnavailable
            #endif
        }
    }

    public static func make(
        host: String,
        port: UInt16,
        backend: AsyncTransportBackend,
        proxy: ProxySettings?
    ) async throws -> AsyncTransport {
        guard let proxy else {
            return try make(host: host, port: port, backend: backend)
        }

        let transport = try make(host: proxy.host, port: UInt16(proxy.port), backend: backend)
        do {
            try await transport.start()
            let client = AsyncProxyClientFactory.make(transport: transport, settings: proxy)
            let leftover = try await client.connect(to: host, port: Int(port))
            if !leftover.isEmpty {
                if let tlsTransport = transport as? AsyncStartTlsTransport {
                    return BufferedAsyncStartTlsTransport(transport: tlsTransport, prebuffer: leftover)
                }
                return BufferedAsyncTransport(transport: transport, prebuffer: leftover)
            }
            return transport
        } catch {
            await transport.stop()
            throw error
        }
    }
}
