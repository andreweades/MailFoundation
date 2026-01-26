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
// TransportFactory.swift
//
// Synchronous transport factory helpers.
//

// MARK: - Transport Backend

/// Specifies the underlying implementation for synchronous transports.
///
/// Different backends may be available depending on the platform and
/// provide different performance characteristics.
public enum TransportBackend: Sendable {
    /// TCP transport using Foundation networking.
    ///
    /// This is the most portable option and works on all Apple platforms.
    case tcp

    /// POSIX socket-based transport.
    ///
    /// This provides lower-level socket access and may offer better
    /// performance in some scenarios.
    ///
    /// - Note: Not available on iOS.
    case socket
}

// MARK: - Transport Factory Error

/// Errors that can occur when creating transports.
public enum TransportFactoryError: Error, Sendable {
    /// The requested backend is not available on this platform.
    ///
    /// Some backends (like ``TransportBackend/socket``) are not available
    /// on all platforms.
    case backendUnavailable
}

// MARK: - Transport Factory

/// A factory for creating synchronous transport instances.
///
/// `TransportFactory` provides a convenient way to create transport
/// instances with optional proxy support. It handles the details of
/// connecting through proxies and selecting the appropriate transport
/// implementation.
///
/// ## Basic Usage
///
/// ```swift
/// // Create a direct TCP transport
/// let transport = try TransportFactory.make(
///     host: "smtp.example.com",
///     port: 587,
///     backend: .tcp
/// )
/// transport.open()
/// ```
///
/// ## With Proxy
///
/// ```swift
/// // Create a transport through an HTTP proxy
/// let proxy = ProxySettings(
///     host: "proxy.example.com",
///     port: 8080,
///     type: .httpConnect
/// )
///
/// let transport = try TransportFactory.make(
///     host: "smtp.example.com",
///     port: 587,
///     backend: .tcp,
///     proxy: proxy
/// )
/// // Proxy negotiation happens during make()
/// // Transport is ready to use
/// ```
///
/// - Note: When a proxy is specified, the factory handles the proxy
///   negotiation automatically. The returned transport is already
///   connected through the proxy to the target host.
public enum TransportFactory {
    /// Creates a transport to the specified host.
    ///
    /// This method creates and optionally configures a transport for
    /// connecting to a mail server. If proxy settings are provided,
    /// the proxy connection is established before returning.
    ///
    /// - Parameters:
    ///   - host: The target host to connect to.
    ///   - port: The target port to connect to.
    ///   - backend: The transport backend to use.
    ///   - proxy: Optional proxy settings for tunneled connections.
    /// - Returns: A configured transport ready for use.
    /// - Throws: ``TransportFactoryError/backendUnavailable`` if the backend
    ///   is not available, or ``ProxyError`` if proxy connection fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let transport = try TransportFactory.make(
    ///     host: "imap.example.com",
    ///     port: 993,
    ///     backend: .tcp
    /// )
    /// transport.open()
    /// defer { transport.close() }
    /// ```
    public static func make(
        host: String,
        port: Int,
        backend: TransportBackend,
        proxy: ProxySettings? = nil
    ) throws -> Transport {
        if let proxy {
            let transport = try makeDirect(host: proxy.host, port: proxy.port, backend: backend)
            transport.open()
            let client = ProxyClientFactory.make(transport: transport, settings: proxy)
            do {
                try client.connect(to: host, port: port)
            } catch {
                transport.close()
                throw error
            }
            return transport
        }
        return try makeDirect(host: host, port: port, backend: backend)
    }

    /// Creates a direct transport without proxy support.
    ///
    /// - Parameters:
    ///   - host: The host to connect to.
    ///   - port: The port to connect to.
    ///   - backend: The transport backend to use.
    /// - Returns: A new transport instance.
    /// - Throws: ``TransportFactoryError/backendUnavailable`` if the backend
    ///   is not available on this platform.
    private static func makeDirect(host: String, port: Int, backend: TransportBackend) throws -> Transport {
        switch backend {
        case .tcp:
            return TcpTransport(host: host, port: port)
        case .socket:
            #if !os(iOS)
            return PosixSocketTransport(host: host, port: UInt16(port))
            #else
            throw TransportFactoryError.backendUnavailable
            #endif
        }
    }
}
