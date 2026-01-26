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
}
