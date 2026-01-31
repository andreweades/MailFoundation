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
// ProxySupport.swift
//
// Proxy client implementations and settings.
//

import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// MARK: - Proxy Type

/// The type of proxy protocol to use for tunneled connections.
///
/// Different proxy protocols have different capabilities and authentication
/// mechanisms. Choose the appropriate type based on your proxy server's
/// support and your requirements.
///
/// For a detailed guide on using proxies with MailFoundation, see <doc:ProxySupport>.
///
/// - Note: Ported from MailKit's `ProxyClient` implementations.
public enum ProxyType: Sendable, Equatable {
    /// HTTP CONNECT proxy (HTTP tunneling).
    ///
    /// Uses the HTTP CONNECT method to establish a tunnel through an
    /// HTTP proxy. This is commonly used for HTTPS proxying and works
    /// well with mail protocols.
    ///
    /// Supports Basic authentication via username/password.
    case httpConnect

    /// SOCKS4 proxy protocol.
    ///
    /// An older SOCKS protocol that supports TCP connections but has
    /// limited authentication (user ID only, no password).
    ///
    /// - Note: Use ``useSocks4a`` in ``ProxySettings`` to enable
    ///   domain name resolution by the proxy server.
    case socks4

    /// SOCKS5 proxy protocol.
    ///
    /// A more capable proxy protocol supporting TCP and UDP, as well
    /// as username/password authentication and IPv6 addresses.
    case socks5
}

// MARK: - Proxy Settings

/// Configuration settings for connecting through a proxy server.
///
/// `ProxySettings` contains all the information needed to establish
/// a connection through an HTTP CONNECT, SOCKS4, or SOCKS5 proxy.
///
/// For a detailed guide and examples, see <doc:ProxySupport>.
///
/// ## Basic Configuration
///
/// ```swift
/// // HTTP CONNECT proxy without authentication
/// let proxy = ProxySettings(
///     host: "proxy.example.com",
///     port: 8080,
///     type: .httpConnect
/// )
/// ```
///
/// ## With Authentication
///
/// ```swift
/// // SOCKS5 proxy with username/password
/// let proxy = ProxySettings(
///     host: "socks.example.com",
///     port: 1080,
///     type: .socks5,
///     username: "user",
///     password: "secret"
/// )
/// ```
///
/// ## With Custom Headers (HTTP CONNECT)
///
/// ```swift
/// let proxy = ProxySettings(
///     host: "proxy.example.com",
///     port: 8080,
///     type: .httpConnect,
///     headers: ["X-Custom-Header": "value"]
/// )
/// ```
///
/// - Note: Ported from MailKit's proxy client configuration.
public struct ProxySettings: Sendable, Equatable {
    /// The proxy server hostname or IP address.
    public var host: String

    /// The proxy server port number.
    public var port: Int

    /// The proxy protocol type.
    public var type: ProxyType

    /// Username for proxy authentication (SOCKS5, HTTP CONNECT).
    public var username: String?

    /// Password for proxy authentication (SOCKS5, HTTP CONNECT).
    public var password: String?

    /// User ID for SOCKS4 authentication.
    ///
    /// If not specified and ``username`` is set, the username is used.
    public var userId: String?

    /// Whether to use SOCKS4a protocol extensions.
    ///
    /// When `true`, domain names are sent to the proxy for resolution
    /// rather than resolving them locally. This is useful when the
    /// client cannot resolve the target hostname.
    ///
    /// - Note: Only applies to ``ProxyType/socks4``.
    public var useSocks4a: Bool

    /// Maximum number of read attempts during proxy negotiation.
    ///
    /// The proxy client will attempt to read responses up to this
    /// many times before timing out.
    public var maxReads: Int

    /// Timeout for proxy negotiation in milliseconds.
    public var timeoutMilliseconds: Int

    /// Additional HTTP headers to send during CONNECT (HTTP CONNECT only).
    ///
    /// These headers are included in the HTTP CONNECT request and can
    /// be used for custom proxy authentication or identification.
    public var headers: [String: String]

    /// Creates proxy settings with the specified configuration.
    ///
    /// - Parameters:
    ///   - host: The proxy server hostname.
    ///   - port: The proxy server port.
    ///   - type: The proxy protocol type.
    ///   - username: Username for authentication (optional).
    ///   - password: Password for authentication (optional).
    ///   - userId: SOCKS4 user ID (optional, defaults to username).
    ///   - useSocks4a: Use SOCKS4a domain resolution (default: `true`).
    ///   - maxReads: Maximum read attempts (default: 10).
    ///   - timeoutMilliseconds: Negotiation timeout (default: 2 minutes).
    ///   - headers: Additional HTTP headers for CONNECT (default: empty).
    public init(
        host: String,
        port: Int,
        type: ProxyType,
        username: String? = nil,
        password: String? = nil,
        userId: String? = nil,
        useSocks4a: Bool = true,
        maxReads: Int = 10,
        timeoutMilliseconds: Int = defaultServiceTimeoutMs,
        headers: [String: String] = [:]
    ) {
        self.host = host
        self.port = port
        self.type = type
        self.username = username
        self.password = password
        self.userId = userId
        self.useSocks4a = useSocks4a
        self.maxReads = max(1, maxReads)
        self.timeoutMilliseconds = timeoutMilliseconds
        self.headers = headers
    }
}

// MARK: - Proxy Error

/// Errors that can occur during proxy connection negotiation.
///
/// These errors indicate failures in establishing a tunnel through
/// the proxy server to the target mail server.
public enum ProxyError: Error, Sendable, Equatable {
    /// The proxy negotiation timed out.
    ///
    /// The proxy server did not respond within the allowed time.
    case timeout

    /// Failed to write to the transport during proxy negotiation.
    case transportWriteFailed

    /// The proxy server sent an invalid or unexpected response.
    case invalidResponse

    /// Proxy authentication failed.
    ///
    /// The provided credentials were rejected by the proxy server.
    case authenticationFailed

    /// The target address type is not supported.
    ///
    /// This can occur with SOCKS4 when trying to connect to an IPv6
    /// address or a domain name without SOCKS4a enabled.
    case unsupportedAddressType

    /// HTTP CONNECT request was rejected.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code (e.g., 403, 407).
    ///   - statusText: The status reason phrase.
    case httpConnectFailed(statusCode: Int, statusText: String)

    /// SOCKS4 connection was rejected.
    ///
    /// - Parameter code: The SOCKS4 reply code (0x5B-0x5D).
    case socks4Rejected(code: UInt8)

    /// SOCKS5 connection was rejected.
    ///
    /// - Parameter code: The SOCKS5 reply code indicating the failure reason.
    case socks5Rejected(code: UInt8)
}

// MARK: - HTTP Proxy Client

/// A synchronous proxy client implementing HTTP CONNECT tunneling.
///
/// `HttpProxyClient` establishes a tunnel through an HTTP proxy using the
/// CONNECT method. This is commonly used for HTTPS proxying and works
/// well with mail protocols.
///
/// ## Protocol Overview
///
/// 1. Connect to proxy server
/// 2. Send HTTP CONNECT request with target host:port
/// 3. Receive 200 response if successful
/// 4. Tunnel is established; subsequent data goes to target
///
/// ## Authentication
///
/// Supports HTTP Basic authentication via `Proxy-Authorization` header.
///
/// - Note: Ported from MailKit's `HttpProxyClient`.
public final class HttpProxyClient: ProxyClient {
    private let transport: Transport
    private let username: String?
    private let password: String?
    private let maxReads: Int
    private let headers: [String: String]

    /// Creates an HTTP proxy client.
    ///
    /// - Parameters:
    ///   - transport: The transport connected to the proxy server.
    ///   - username: Username for Basic authentication (optional).
    ///   - password: Password for Basic authentication (optional).
    ///   - maxReads: Maximum read attempts for the response.
    ///   - headers: Additional headers to include in the CONNECT request.
    public init(
        transport: Transport,
        username: String? = nil,
        password: String? = nil,
        maxReads: Int = 10,
        headers: [String: String] = [:]
    ) {
        self.transport = transport
        self.username = username
        self.password = password
        self.maxReads = max(1, maxReads)
        self.headers = headers
    }

    /// Establishes a tunnel to the target host through the HTTP proxy.
    ///
    /// - Parameters:
    ///   - host: The target hostname to connect to.
    ///   - port: The target port to connect to.
    /// - Throws: ``ProxyError/httpConnectFailed(statusCode:statusText:)`` if
    ///   the proxy rejects the connection, or ``ProxyError/invalidResponse``
    ///   if the proxy response cannot be parsed.
    public func connect(to host: String, port: Int) throws {
        let authority = "\(host):\(port)"
        var lines: [String] = [
            "CONNECT \(authority) HTTP/1.1",
            "Host: \(authority)",
            "Proxy-Connection: Keep-Alive"
        ]
        if let username, let password {
            let token = Data("\(username):\(password)".utf8).base64EncodedString()
            lines.append("Proxy-Authorization: Basic \(token)")
        }
        for (name, value) in headers {
            lines.append("\(name): \(value)")
        }
        let request = lines.joined(separator: "\r\n") + "\r\n\r\n"
        try writeAll(Array(request.utf8), transport: transport)

        var reader = ProxyLineReader(transport: transport, maxReads: maxReads)
        let statusLine = try reader.readLine()
        guard let statusLine else {
            throw ProxyError.invalidResponse
        }

        let parts = statusLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count >= 2, let statusCode = Int(parts[1]) else {
            throw ProxyError.invalidResponse
        }
        let statusText = parts.count >= 3 ? String(parts[2]) : ""

        _ = try reader.readHeaders()

        guard statusCode == 200 else {
            throw ProxyError.httpConnectFailed(statusCode: statusCode, statusText: statusText)
        }
    }
}

// MARK: - SOCKS4 Proxy Client

/// A synchronous proxy client implementing the SOCKS4/4a protocol.
///
/// `Socks4ProxyClient` establishes connections through SOCKS4 proxy servers.
/// SOCKS4 supports TCP connections with optional user ID authentication.
///
/// ## SOCKS4 vs SOCKS4a
///
/// - SOCKS4: Client resolves hostnames; only IPv4 addresses supported
/// - SOCKS4a: Proxy resolves hostnames; domain names can be sent directly
///
/// Enable SOCKS4a mode when the client cannot resolve the target hostname
/// or when you want the proxy to handle DNS resolution.
///
/// - Note: Ported from MailKit's `Socks4Client`.
public final class Socks4ProxyClient: ProxyClient {
    private let transport: Transport
    private let userId: String?
    private let useSocks4a: Bool
    private let maxReads: Int

    /// Creates a SOCKS4 proxy client.
    ///
    /// - Parameters:
    ///   - transport: The transport connected to the proxy server.
    ///   - userId: User ID for SOCKS4 authentication (optional).
    ///   - useSocks4a: Enable SOCKS4a domain name resolution (default: `true`).
    ///   - maxReads: Maximum read attempts for the response.
    public init(
        transport: Transport,
        userId: String? = nil,
        useSocks4a: Bool = true,
        maxReads: Int = 10
    ) {
        self.transport = transport
        self.userId = userId
        self.useSocks4a = useSocks4a
        self.maxReads = max(1, maxReads)
    }

    /// Establishes a connection to the target host through the SOCKS4 proxy.
    ///
    /// - Parameters:
    ///   - host: The target hostname or IPv4 address.
    ///   - port: The target port to connect to.
    /// - Throws: ``ProxyError/socks4Rejected(code:)`` if the proxy rejects
    ///   the connection, or ``ProxyError/unsupportedAddressType`` if the
    ///   host is not an IPv4 address and SOCKS4a is disabled.
    public func connect(to host: String, port: Int) throws {
        let portBytes = encodePort(port)
        let ipv4 = parseIPv4(host)

        var request: [UInt8] = [0x04, 0x01]
        request.append(contentsOf: portBytes)

        if let ipv4 {
            request.append(contentsOf: ipv4)
        } else {
            guard useSocks4a else {
                throw ProxyError.unsupportedAddressType
            }
            request.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        }

        if let userId {
            request.append(contentsOf: Array(userId.utf8))
        }
        request.append(0x00)

        if ipv4 == nil {
            request.append(contentsOf: Array(host.utf8))
            request.append(0x00)
        }

        try writeAll(request, transport: transport)

        var reader = ProxyByteReader(transport: transport, maxReads: maxReads)
        let response = try reader.readBytes(8)
        guard response.count == 8 else {
            throw ProxyError.invalidResponse
        }
        guard response[1] == 0x5A else {
            throw ProxyError.socks4Rejected(code: response[1])
        }
    }
}

// MARK: - SOCKS5 Proxy Client

/// A synchronous proxy client implementing the SOCKS5 protocol.
///
/// `Socks5ProxyClient` establishes connections through SOCKS5 proxy servers.
/// SOCKS5 is the most capable proxy protocol, supporting:
///
/// - TCP and UDP connections
/// - Username/password authentication
/// - IPv4, IPv6, and domain name addressing
///
/// ## Authentication Methods
///
/// The client negotiates authentication with the server:
/// - No authentication (method 0x00)
/// - Username/password (method 0x02)
///
/// If credentials are provided, both methods are offered; otherwise,
/// only no-authentication is offered.
///
/// - Note: Ported from MailKit's `Socks5Client`.
public final class Socks5ProxyClient: ProxyClient {
    private let transport: Transport
    private let username: String?
    private let password: String?
    private let maxReads: Int

    /// Creates a SOCKS5 proxy client.
    ///
    /// - Parameters:
    ///   - transport: The transport connected to the proxy server.
    ///   - username: Username for authentication (optional).
    ///   - password: Password for authentication (optional).
    ///   - maxReads: Maximum read attempts for responses.
    public init(
        transport: Transport,
        username: String? = nil,
        password: String? = nil,
        maxReads: Int = 10
    ) {
        self.transport = transport
        self.username = username
        self.password = password
        self.maxReads = max(1, maxReads)
    }

    /// Establishes a connection to the target host through the SOCKS5 proxy.
    ///
    /// This method performs the SOCKS5 handshake including:
    /// 1. Method negotiation
    /// 2. Authentication (if required)
    /// 3. Connection request
    ///
    /// - Parameters:
    ///   - host: The target hostname, IPv4, or IPv6 address.
    ///   - port: The target port to connect to.
    /// - Throws: ``ProxyError/socks5Rejected(code:)`` if the proxy rejects
    ///   the connection, or ``ProxyError/authenticationFailed`` if
    ///   authentication fails.
    public func connect(to host: String, port: Int) throws {
        var methods: [UInt8] = [0x00]
        if username != nil {
            methods.append(0x02)
        }
        var greeting: [UInt8] = [0x05, UInt8(methods.count)]
        greeting.append(contentsOf: methods)
        try writeAll(greeting, transport: transport)

        var reader = ProxyByteReader(transport: transport, maxReads: maxReads)
        let methodResponse = try reader.readBytes(2)
        guard methodResponse.count == 2, methodResponse[0] == 0x05 else {
            throw ProxyError.invalidResponse
        }
        switch methodResponse[1] {
        case 0x00:
            break
        case 0x02:
            try authenticate(reader: &reader)
        default:
            throw ProxyError.authenticationFailed
        }

        let (addressType, addressBytes) = try encodeSocks5Address(host)
        var request: [UInt8] = [0x05, 0x01, 0x00, addressType]
        request.append(contentsOf: addressBytes)
        request.append(contentsOf: encodePort(port))
        try writeAll(request, transport: transport)

        let header = try reader.readBytes(4)
        guard header.count == 4, header[0] == 0x05 else {
            throw ProxyError.invalidResponse
        }
        guard header[1] == 0x00 else {
            throw ProxyError.socks5Rejected(code: header[1])
        }

        let atyp = header[3]
        switch atyp {
        case 0x01:
            _ = try reader.readBytes(4)
        case 0x04:
            _ = try reader.readBytes(16)
        case 0x03:
            let lengthByte = try reader.readBytes(1)
            guard let length = lengthByte.first else {
                throw ProxyError.invalidResponse
            }
            _ = try reader.readBytes(Int(length))
        default:
            throw ProxyError.invalidResponse
        }
        _ = try reader.readBytes(2)
    }

    private func authenticate(reader: inout ProxyByteReader) throws {
        guard let username, let password else {
            throw ProxyError.authenticationFailed
        }
        let userBytes = Array(username.utf8)
        let passBytes = Array(password.utf8)
        guard userBytes.count <= 255, passBytes.count <= 255 else {
            throw ProxyError.authenticationFailed
        }
        var auth: [UInt8] = [0x01, UInt8(userBytes.count)]
        auth.append(contentsOf: userBytes)
        auth.append(UInt8(passBytes.count))
        auth.append(contentsOf: passBytes)
        try writeAll(auth, transport: transport)

        let response = try reader.readBytes(2)
        guard response.count == 2, response[0] == 0x01, response[1] == 0x00 else {
            throw ProxyError.authenticationFailed
        }
    }

    private func encodeSocks5Address(_ host: String) throws -> (UInt8, [UInt8]) {
        if let ipv4 = parseIPv4(host) {
            return (0x01, ipv4)
        }
        if let ipv6 = parseIPv6(host) {
            return (0x04, ipv6)
        }
        let domainBytes = Array(host.utf8)
        guard domainBytes.count <= 255 else {
            throw ProxyError.unsupportedAddressType
        }
        return (0x03, [UInt8(domainBytes.count)] + domainBytes)
    }
}

internal enum ProxyClientFactory {
    static func make(transport: Transport, settings: ProxySettings) -> ProxyClient {
        switch settings.type {
        case .httpConnect:
            return HttpProxyClient(
                transport: transport,
                username: settings.username,
                password: settings.password,
                maxReads: settings.maxReads,
                headers: settings.headers
            )
        case .socks4:
            return Socks4ProxyClient(
                transport: transport,
                userId: settings.userId ?? settings.username,
                useSocks4a: settings.useSocks4a,
                maxReads: settings.maxReads
            )
        case .socks5:
            return Socks5ProxyClient(
                transport: transport,
                username: settings.username,
                password: settings.password,
                maxReads: settings.maxReads
            )
        }
    }
}

private struct ProxyLineReader {
    private let transport: Transport
    private let maxReads: Int
    private var lineBuffer = LineBuffer()
    private var pendingLines: [String] = []

    init(transport: Transport, maxReads: Int) {
        self.transport = transport
        self.maxReads = maxReads
    }

    mutating func readLine() throws -> String? {
        if !pendingLines.isEmpty {
            return pendingLines.removeFirst()
        }
        var reads = 0
        while reads < maxReads {
            let chunk = transport.readAvailable(maxLength: 4096)
            if chunk.isEmpty {
                reads += 1
                continue
            }
            let lines = lineBuffer.append(chunk)
            if !lines.isEmpty {
                pendingLines.append(contentsOf: lines)
                return pendingLines.removeFirst()
            }
        }
        throw ProxyError.timeout
    }

    mutating func readHeaders() throws -> [String] {
        var headers: [String] = []
        while true {
            let line = try readLine()
            guard let line else { break }
            if line.isEmpty {
                break
            }
            headers.append(line)
        }
        return headers
    }
}

private struct ProxyByteReader {
    private let transport: Transport
    private let maxReads: Int
    private var buffer: [UInt8] = []

    init(transport: Transport, maxReads: Int) {
        self.transport = transport
        self.maxReads = maxReads
    }

    mutating func readBytes(_ count: Int) throws -> [UInt8] {
        var reads = 0
        while buffer.count < count {
            let chunk = transport.readAvailable(maxLength: 4096)
            if chunk.isEmpty {
                reads += 1
                if reads >= maxReads {
                    throw ProxyError.timeout
                }
                continue
            }
            buffer.append(contentsOf: chunk)
        }
        let result = Array(buffer.prefix(count))
        buffer.removeFirst(count)
        return result
    }
}

private func writeAll(_ bytes: [UInt8], transport: Transport) throws {
    let written = transport.write(bytes)
    if written != bytes.count {
        throw ProxyError.transportWriteFailed
    }
}

private func encodePort(_ port: Int) -> [UInt8] {
    let high = UInt8((port >> 8) & 0xFF)
    let low = UInt8(port & 0xFF)
    return [high, low]
}

private func parseIPv4(_ host: String) -> [UInt8]? {
    let parts = host.split(separator: ".")
    guard parts.count == 4 else { return nil }
    var bytes: [UInt8] = []
    bytes.reserveCapacity(4)
    for part in parts {
        guard let value = UInt8(part) else { return nil }
        bytes.append(value)
    }
    return bytes
}

private func parseIPv6(_ host: String) -> [UInt8]? {
    var addr = in6_addr()
    let result = host.withCString { inet_pton(AF_INET6, $0, &addr) }
    guard result == 1 else { return nil }
    return withUnsafeBytes(of: addr) { Array($0) }
}

// MARK: - Async Proxy Clients

/// An asynchronous protocol for proxy client implementations.
///
/// Async proxy clients establish tunneled connections through proxy
/// servers using async/await. They return any bytes received after
/// the proxy negotiation completes (which should be forwarded to the
/// protocol layer).
@available(macOS 10.15, iOS 13.0, *)
public protocol AsyncProxyClient: AnyObject, Sendable {
    /// Establishes a connection to the target host through the proxy.
    ///
    /// - Parameters:
    ///   - host: The target hostname to connect to.
    ///   - port: The target port to connect to.
    /// - Returns: Any bytes received after proxy negotiation that should
    ///   be forwarded to the protocol handler.
    /// - Throws: ``ProxyError`` if the proxy connection fails.
    func connect(to host: String, port: Int) async throws -> [UInt8]
}

// MARK: - Async HTTP Proxy Client

/// An asynchronous proxy client implementing HTTP CONNECT tunneling.
///
/// This is the async version of ``HttpProxyClient``. See that class
/// for protocol details.
///
/// - Note: Available on macOS 10.15+ and iOS 13.0+.
@available(macOS 10.15, iOS 13.0, *)
public final class AsyncHttpProxyClient: AsyncProxyClient {
    private let transport: AsyncTransport
    private let username: String?
    private let password: String?
    private let timeoutMilliseconds: Int
    private let headers: [String: String]

    /// Creates an async HTTP proxy client.
    ///
    /// - Parameters:
    ///   - transport: The async transport connected to the proxy server.
    ///   - username: Username for Basic authentication (optional).
    ///   - password: Password for Basic authentication (optional).
    ///   - timeoutMilliseconds: Negotiation timeout in milliseconds.
    ///   - headers: Additional headers for the CONNECT request.
    public init(
        transport: AsyncTransport,
        username: String? = nil,
        password: String? = nil,
        timeoutMilliseconds: Int = defaultServiceTimeoutMs,
        headers: [String: String] = [:]
    ) {
        self.transport = transport
        self.username = username
        self.password = password
        self.timeoutMilliseconds = timeoutMilliseconds
        self.headers = headers
    }

    /// Establishes a tunnel to the target host through the HTTP proxy.
    ///
    /// - Parameters:
    ///   - host: The target hostname.
    ///   - port: The target port.
    /// - Returns: Any bytes received after the proxy response.
    /// - Throws: ``ProxyError`` if the connection fails.
    public func connect(to host: String, port: Int) async throws -> [UInt8] {
        let authority = "\(host):\(port)"
        var lines: [String] = [
            "CONNECT \(authority) HTTP/1.1",
            "Host: \(authority)",
            "Proxy-Connection: Keep-Alive"
        ]
        if let username, let password {
            let token = Data("\(username):\(password)".utf8).base64EncodedString()
            lines.append("Proxy-Authorization: Basic \(token)")
        }
        for (name, value) in headers {
            lines.append("\(name): \(value)")
        }
        let request = lines.joined(separator: "\r\n") + "\r\n\r\n"
        try await transport.send(Array(request.utf8))

        var reader = AsyncProxyLineReader(
            iterator: transport.incoming.makeAsyncIterator(),
            timeoutMilliseconds: timeoutMilliseconds
        )
        let statusLine = try await reader.readLine()
        guard let statusLine else {
            throw ProxyError.invalidResponse
        }

        let parts = statusLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count >= 2, let statusCode = Int(parts[1]) else {
            throw ProxyError.invalidResponse
        }
        let statusText = parts.count >= 3 ? String(parts[2]) : ""

        _ = try await reader.readHeaders()

        guard statusCode == 200 else {
            throw ProxyError.httpConnectFailed(statusCode: statusCode, statusText: statusText)
        }
        return reader.remainingBytes()
    }
}

// MARK: - Async SOCKS4 Proxy Client

/// An asynchronous proxy client implementing the SOCKS4/4a protocol.
///
/// This is the async version of ``Socks4ProxyClient``. See that class
/// for protocol details.
///
/// - Note: Available on macOS 10.15+ and iOS 13.0+.
@available(macOS 10.15, iOS 13.0, *)
public final class AsyncSocks4ProxyClient: AsyncProxyClient {
    private let transport: AsyncTransport
    private let userId: String?
    private let useSocks4a: Bool
    private let timeoutMilliseconds: Int

    /// Creates an async SOCKS4 proxy client.
    ///
    /// - Parameters:
    ///   - transport: The async transport connected to the proxy server.
    ///   - userId: User ID for SOCKS4 authentication (optional).
    ///   - useSocks4a: Enable SOCKS4a domain resolution (default: `true`).
    ///   - timeoutMilliseconds: Negotiation timeout in milliseconds.
    public init(
        transport: AsyncTransport,
        userId: String? = nil,
        useSocks4a: Bool = true,
        timeoutMilliseconds: Int = defaultServiceTimeoutMs
    ) {
        self.transport = transport
        self.userId = userId
        self.useSocks4a = useSocks4a
        self.timeoutMilliseconds = timeoutMilliseconds
    }

    /// Establishes a connection to the target host through the SOCKS4 proxy.
    ///
    /// - Parameters:
    ///   - host: The target hostname or IPv4 address.
    ///   - port: The target port.
    /// - Returns: Any bytes received after the proxy response.
    /// - Throws: ``ProxyError`` if the connection fails.
    public func connect(to host: String, port: Int) async throws -> [UInt8] {
        let portBytes = encodePort(port)
        let ipv4 = parseIPv4(host)

        var request: [UInt8] = [0x04, 0x01]
        request.append(contentsOf: portBytes)

        if let ipv4 {
            request.append(contentsOf: ipv4)
        } else {
            guard useSocks4a else {
                throw ProxyError.unsupportedAddressType
            }
            request.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        }

        if let userId {
            request.append(contentsOf: Array(userId.utf8))
        }
        request.append(0x00)

        if ipv4 == nil {
            request.append(contentsOf: Array(host.utf8))
            request.append(0x00)
        }

        try await transport.send(request)

        var reader = AsyncProxyByteReader(
            iterator: transport.incoming.makeAsyncIterator(),
            timeoutMilliseconds: timeoutMilliseconds
        )
        let response = try await reader.readBytes(8)
        guard response.count == 8 else {
            throw ProxyError.invalidResponse
        }
        guard response[1] == 0x5A else {
            throw ProxyError.socks4Rejected(code: response[1])
        }
        return reader.remainingBytes()
    }
}

// MARK: - Async SOCKS5 Proxy Client

/// An asynchronous proxy client implementing the SOCKS5 protocol.
///
/// This is the async version of ``Socks5ProxyClient``. See that class
/// for protocol details.
///
/// - Note: Available on macOS 10.15+ and iOS 13.0+.
@available(macOS 10.15, iOS 13.0, *)
public final class AsyncSocks5ProxyClient: AsyncProxyClient {
    private let transport: AsyncTransport
    private let username: String?
    private let password: String?
    private let timeoutMilliseconds: Int

    /// Creates an async SOCKS5 proxy client.
    ///
    /// - Parameters:
    ///   - transport: The async transport connected to the proxy server.
    ///   - username: Username for authentication (optional).
    ///   - password: Password for authentication (optional).
    ///   - timeoutMilliseconds: Negotiation timeout in milliseconds.
    public init(
        transport: AsyncTransport,
        username: String? = nil,
        password: String? = nil,
        timeoutMilliseconds: Int = defaultServiceTimeoutMs
    ) {
        self.transport = transport
        self.username = username
        self.password = password
        self.timeoutMilliseconds = timeoutMilliseconds
    }

    /// Establishes a connection to the target host through the SOCKS5 proxy.
    ///
    /// - Parameters:
    ///   - host: The target hostname, IPv4, or IPv6 address.
    ///   - port: The target port.
    /// - Returns: Any bytes received after the proxy response.
    /// - Throws: ``ProxyError`` if the connection fails.
    public func connect(to host: String, port: Int) async throws -> [UInt8] {
        var methods: [UInt8] = [0x00]
        if username != nil {
            methods.append(0x02)
        }
        var greeting: [UInt8] = [0x05, UInt8(methods.count)]
        greeting.append(contentsOf: methods)
        try await transport.send(greeting)

        var reader = AsyncProxyByteReader(
            iterator: transport.incoming.makeAsyncIterator(),
            timeoutMilliseconds: timeoutMilliseconds
        )
        let methodResponse = try await reader.readBytes(2)
        guard methodResponse.count == 2, methodResponse[0] == 0x05 else {
            throw ProxyError.invalidResponse
        }
        switch methodResponse[1] {
        case 0x00:
            break
        case 0x02:
            try await authenticate(reader: &reader)
        default:
            throw ProxyError.authenticationFailed
        }

        let (addressType, addressBytes) = try encodeSocks5Address(host)
        var request: [UInt8] = [0x05, 0x01, 0x00, addressType]
        request.append(contentsOf: addressBytes)
        request.append(contentsOf: encodePort(port))
        try await transport.send(request)

        let header = try await reader.readBytes(4)
        guard header.count == 4, header[0] == 0x05 else {
            throw ProxyError.invalidResponse
        }
        guard header[1] == 0x00 else {
            throw ProxyError.socks5Rejected(code: header[1])
        }

        let atyp = header[3]
        switch atyp {
        case 0x01:
            _ = try await reader.readBytes(4)
        case 0x04:
            _ = try await reader.readBytes(16)
        case 0x03:
            let lengthByte = try await reader.readBytes(1)
            guard let length = lengthByte.first else {
                throw ProxyError.invalidResponse
            }
            _ = try await reader.readBytes(Int(length))
        default:
            throw ProxyError.invalidResponse
        }
        _ = try await reader.readBytes(2)
        return reader.remainingBytes()
    }

    private func authenticate(reader: inout AsyncProxyByteReader) async throws {
        guard let username, let password else {
            throw ProxyError.authenticationFailed
        }
        let userBytes = Array(username.utf8)
        let passBytes = Array(password.utf8)
        guard userBytes.count <= 255, passBytes.count <= 255 else {
            throw ProxyError.authenticationFailed
        }
        var auth: [UInt8] = [0x01, UInt8(userBytes.count)]
        auth.append(contentsOf: userBytes)
        auth.append(UInt8(passBytes.count))
        auth.append(contentsOf: passBytes)
        try await transport.send(auth)

        let response = try await reader.readBytes(2)
        guard response.count == 2, response[0] == 0x01, response[1] == 0x00 else {
            throw ProxyError.authenticationFailed
        }
    }

    private func encodeSocks5Address(_ host: String) throws -> (UInt8, [UInt8]) {
        if let ipv4 = parseIPv4(host) {
            return (0x01, ipv4)
        }
        if let ipv6 = parseIPv6(host) {
            return (0x04, ipv6)
        }
        let domainBytes = Array(host.utf8)
        guard domainBytes.count <= 255 else {
            throw ProxyError.unsupportedAddressType
        }
        return (0x03, [UInt8(domainBytes.count)] + domainBytes)
    }
}

@available(macOS 10.15, iOS 13.0, *)
internal enum AsyncProxyClientFactory {
    static func make(transport: AsyncTransport, settings: ProxySettings) -> AsyncProxyClient {
        switch settings.type {
        case .httpConnect:
            return AsyncHttpProxyClient(
                transport: transport,
                username: settings.username,
                password: settings.password,
                timeoutMilliseconds: settings.timeoutMilliseconds,
                headers: settings.headers
            )
        case .socks4:
            return AsyncSocks4ProxyClient(
                transport: transport,
                userId: settings.userId ?? settings.username,
                useSocks4a: settings.useSocks4a,
                timeoutMilliseconds: settings.timeoutMilliseconds
            )
        case .socks5:
            return AsyncSocks5ProxyClient(
                transport: transport,
                username: settings.username,
                password: settings.password,
                timeoutMilliseconds: settings.timeoutMilliseconds
            )
        }
    }
}

@available(macOS 10.15, iOS 13.0, *)
internal actor BufferedAsyncTransport: AsyncTransport {
    public nonisolated let incoming: AsyncStream<[UInt8]>
    private let continuation: AsyncStream<[UInt8]>.Continuation
    private let transport: AsyncTransport
    private var forwardTask: Task<Void, Never>?
    private var prebuffer: [UInt8]
    private var started = false
    private var finished = false

    init(transport: AsyncTransport, prebuffer: [UInt8]) {
        self.transport = transport
        self.prebuffer = prebuffer
        var continuation: AsyncStream<[UInt8]>.Continuation!
        self.incoming = AsyncStream { cont in
            continuation = cont
        }
        self.continuation = continuation
    }

    public func start() async throws {
        guard !started else { return }
        started = true
        try await transport.start()
        if !prebuffer.isEmpty {
            continuation.yield(prebuffer)
            prebuffer.removeAll(keepingCapacity: false)
        }
        forwardTask = Task { await forwardLoop() }
    }

    public func stop() async {
        guard started else { return }
        started = false
        forwardTask?.cancel()
        forwardTask = nil
        await transport.stop()
        finish()
    }

    public func send(_ bytes: [UInt8]) async throws {
        try await transport.send(bytes)
    }

    private func forwardLoop() async {
        var iterator = transport.incoming.makeAsyncIterator()
        while let chunk = await iterator.next() {
            if !chunk.isEmpty {
                continuation.yield(chunk)
            }
        }
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        continuation.finish()
    }
}

@available(macOS 10.15, iOS 13.0, *)
internal actor BufferedAsyncStartTlsTransport: AsyncStartTlsTransport {
    public nonisolated let incoming: AsyncStream<[UInt8]>
    private let continuation: AsyncStream<[UInt8]>.Continuation
    private let transport: AsyncStartTlsTransport
    private var forwardTask: Task<Void, Never>?
    private var prebuffer: [UInt8]
    private var started = false
    private var finished = false
    private var scramChannelBindingCache: ScramChannelBinding?

    init(transport: AsyncStartTlsTransport, prebuffer: [UInt8]) {
        self.transport = transport
        self.prebuffer = prebuffer
        var continuation: AsyncStream<[UInt8]>.Continuation!
        self.incoming = AsyncStream { cont in
            continuation = cont
        }
        self.continuation = continuation
    }

    public var scramChannelBinding: ScramChannelBinding? {
        get async {
            scramChannelBindingCache
        }
    }

    public func start() async throws {
        guard !started else { return }
        started = true
        try await transport.start()
        if !prebuffer.isEmpty {
            continuation.yield(prebuffer)
            prebuffer.removeAll(keepingCapacity: false)
        }
        forwardTask = Task { await forwardLoop() }
    }

    public func stop() async {
        guard started else { return }
        started = false
        forwardTask?.cancel()
        forwardTask = nil
        await transport.stop()
        scramChannelBindingCache = nil
        finish()
    }

    public func send(_ bytes: [UInt8]) async throws {
        try await transport.send(bytes)
    }

    public func startTLS(validateCertificate: Bool) async throws {
        try await transport.startTLS(validateCertificate: validateCertificate)
        scramChannelBindingCache = await transport.scramChannelBinding
    }

    private func forwardLoop() async {
        var iterator = transport.incoming.makeAsyncIterator()
        while let chunk = await iterator.next() {
            if !chunk.isEmpty {
                continuation.yield(chunk)
            }
        }
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        continuation.finish()
    }
}

@available(macOS 10.15, iOS 13.0, *)
private struct AsyncProxyLineReader {
    private var iterator: AsyncStream<[UInt8]>.AsyncIterator
    private var buffer: [UInt8] = []
    private let timeoutMilliseconds: Int

    init(
        iterator: AsyncStream<[UInt8]>.AsyncIterator,
        timeoutMilliseconds: Int
    ) {
        self.iterator = iterator
        self.timeoutMilliseconds = timeoutMilliseconds
    }

    mutating func readLine() async throws -> String? {
        if let line = extractLine() {
            return line
        }
        while true {
            let chunk = try await nextChunk()
            if chunk.isEmpty {
                continue
            }
            buffer.append(contentsOf: chunk)
            if let line = extractLine() {
                return line
            }
        }
    }

    mutating func readHeaders() async throws -> [String] {
        var headers: [String] = []
        while true {
            let line = try await readLine()
            guard let line else { break }
            if line.isEmpty {
                break
            }
            headers.append(line)
        }
        return headers
    }

    func remainingBytes() -> [UInt8] {
        buffer
    }

    private mutating func extractLine() -> String? {
        guard let newlineIndex = buffer.firstIndex(of: 0x0A) else {
            return nil
        }
        var end = newlineIndex
        if end > 0 && buffer[end - 1] == 0x0D {
            end -= 1
        }
        let lineBytes = buffer[0..<end]
        buffer.removeFirst(newlineIndex + 1)
        return String(decoding: lineBytes, as: UTF8.self)
    }

    private mutating func nextChunk() async throws -> [UInt8] {
        guard let chunk = await iterator.next() else {
            throw ProxyError.timeout
        }
        return chunk
    }
}

@available(macOS 10.15, iOS 13.0, *)
private struct AsyncProxyByteReader {
    private var iterator: AsyncStream<[UInt8]>.AsyncIterator
    private var buffer: [UInt8] = []
    private let timeoutMilliseconds: Int

    init(
        iterator: AsyncStream<[UInt8]>.AsyncIterator,
        timeoutMilliseconds: Int
    ) {
        self.iterator = iterator
        self.timeoutMilliseconds = timeoutMilliseconds
    }

    mutating func readBytes(_ count: Int) async throws -> [UInt8] {
        while buffer.count < count {
            let chunk = try await nextChunk()
            buffer.append(contentsOf: chunk)
        }
        let result = Array(buffer.prefix(count))
        buffer.removeFirst(count)
        return result
    }

    func remainingBytes() -> [UInt8] {
        buffer
    }

    private mutating func nextChunk() async throws -> [UInt8] {
        guard let chunk = await iterator.next() else {
            throw ProxyError.timeout
        }
        return chunk
    }
}
