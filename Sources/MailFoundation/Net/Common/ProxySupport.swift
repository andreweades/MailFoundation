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

public enum ProxyType: Sendable, Equatable {
    case httpConnect
    case socks4
    case socks5
}

public struct ProxySettings: Sendable, Equatable {
    public var host: String
    public var port: Int
    public var type: ProxyType
    public var username: String?
    public var password: String?
    public var userId: String?
    public var useSocks4a: Bool
    public var maxReads: Int
    public var timeoutMilliseconds: Int
    public var headers: [String: String]

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

public enum ProxyError: Error, Sendable, Equatable {
    case timeout
    case transportWriteFailed
    case invalidResponse
    case authenticationFailed
    case unsupportedAddressType
    case httpConnectFailed(statusCode: Int, statusText: String)
    case socks4Rejected(code: UInt8)
    case socks5Rejected(code: UInt8)
}

public final class HttpProxyClient: ProxyClient {
    private let transport: Transport
    private let username: String?
    private let password: String?
    private let maxReads: Int
    private let headers: [String: String]

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

public final class Socks4ProxyClient: ProxyClient {
    private let transport: Transport
    private let userId: String?
    private let useSocks4a: Bool
    private let maxReads: Int

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

public final class Socks5ProxyClient: ProxyClient {
    private let transport: Transport
    private let username: String?
    private let password: String?
    private let maxReads: Int

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

@available(macOS 10.15, iOS 13.0, *)
public protocol AsyncProxyClient: AnyObject, Sendable {
    func connect(to host: String, port: Int) async throws -> [UInt8]
}

@available(macOS 10.15, iOS 13.0, *)
public final class AsyncHttpProxyClient: AsyncProxyClient {
    private let transport: AsyncTransport
    private let username: String?
    private let password: String?
    private let timeoutMilliseconds: Int
    private let headers: [String: String]

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

@available(macOS 10.15, iOS 13.0, *)
public final class AsyncSocks4ProxyClient: AsyncProxyClient {
    private let transport: AsyncTransport
    private let userId: String?
    private let useSocks4a: Bool
    private let timeoutMilliseconds: Int

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

@available(macOS 10.15, iOS 13.0, *)
public final class AsyncSocks5ProxyClient: AsyncProxyClient {
    private let transport: AsyncTransport
    private let username: String?
    private let password: String?
    private let timeoutMilliseconds: Int

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

    init(transport: AsyncStartTlsTransport, prebuffer: [UInt8]) {
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

    public func startTLS(validateCertificate: Bool) async throws {
        try await transport.startTLS(validateCertificate: validateCertificate)
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
