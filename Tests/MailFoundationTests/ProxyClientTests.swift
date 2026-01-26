import Testing
@testable import MailFoundation

@Test("HTTP CONNECT proxy client sends CONNECT and accepts 200")
func httpProxyClientConnect() throws {
    let transport = TestTransport(incoming: [
        Array("HTTP/1.1 200 Connection established\r\n\r\n".utf8)
    ])
    let client = HttpProxyClient(
        transport: transport,
        username: "user",
        password: "pass"
    )

    try client.connect(to: "imap.example.com", port: 993)

    let sent = String(decoding: transport.written.first ?? [], as: UTF8.self)
    #expect(sent.contains("CONNECT imap.example.com:993 HTTP/1.1\r\n"))
    #expect(sent.contains("Host: imap.example.com:993\r\n"))
    #expect(sent.contains("Proxy-Authorization: Basic "))
}

@Test("SOCKS5 proxy client sends greeting and connect request")
func socks5ProxyClientConnect() throws {
    let transport = TestTransport(incoming: [
        [0x05, 0x00],
        [0x05, 0x00, 0x00, 0x01, 127, 0, 0, 1, 0x1F, 0x90]
    ])
    let client = Socks5ProxyClient(transport: transport)

    try client.connect(to: "127.0.0.1", port: 8080)

    #expect(transport.written.count == 2)
    #expect(transport.written[0] == [0x05, 0x01, 0x00])
    #expect(transport.written[1] == [0x05, 0x01, 0x00, 0x01, 127, 0, 0, 1, 0x1F, 0x90])
}

@Test("SOCKS4 proxy client uses SOCKS4a for domain")
func socks4ProxyClientDomainConnect() throws {
    let transport = TestTransport(incoming: [
        [0x00, 0x5A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    ])
    let client = Socks4ProxyClient(transport: transport, userId: "user", useSocks4a: true)

    try client.connect(to: "example.com", port: 110)

    let sent = transport.written.first ?? []
    #expect(sent.count > 9)
    #expect(Array(sent.prefix(4)) == [0x04, 0x01, 0x00, 0x6E])
    #expect(Array(sent[4..<8]) == [0x00, 0x00, 0x00, 0x01])
    #expect(sent.contains(0x00))
}

@available(macOS 10.15, iOS 13.0, *)
@Test("Async HTTP CONNECT proxy client sends CONNECT and accepts 200")
func asyncHttpProxyClientConnect() async throws {
    let transport = AsyncStreamTransport()
    try await transport.start()

    let client = AsyncHttpProxyClient(
        transport: transport,
        username: "user",
        password: "pass",
        timeoutMilliseconds: 5_000
    )

    let connectTask = Task {
        try await client.connect(to: "imap.example.com", port: 993)
    }
    await transport.yieldIncoming(Array("HTTP/1.1 200 Connection established\r\n\r\n".utf8))
    _ = try await connectTask.value

    let sent = await transport.sentSnapshot()
    let sentText = String(decoding: sent.first ?? [], as: UTF8.self)
    #expect(sentText.contains("CONNECT imap.example.com:993 HTTP/1.1\r\n"))
    #expect(sentText.contains("Host: imap.example.com:993\r\n"))
    #expect(sentText.contains("Proxy-Authorization: Basic "))
}

@available(macOS 10.15, iOS 13.0, *)
@Test("Async SOCKS5 proxy client sends greeting and connect request")
func asyncSocks5ProxyClientConnect() async throws {
    let transport = AsyncStreamTransport()
    try await transport.start()

    let client = AsyncSocks5ProxyClient(transport: transport, timeoutMilliseconds: 5_000)

    let connectTask = Task {
        try await client.connect(to: "127.0.0.1", port: 8080)
    }
    await transport.yieldIncoming([0x05, 0x00])
    await transport.yieldIncoming([0x05, 0x00, 0x00, 0x01, 127, 0, 0, 1, 0x1F, 0x90])
    _ = try await connectTask.value

    let sent = await transport.sentSnapshot()
    #expect(sent.count == 2)
    #expect(sent[0] == [0x05, 0x01, 0x00])
    #expect(sent[1] == [0x05, 0x01, 0x00, 0x01, 127, 0, 0, 1, 0x1F, 0x90])
}

@available(macOS 10.15, iOS 13.0, *)
@Test("Async SOCKS4 proxy client uses SOCKS4a for domain")
func asyncSocks4ProxyClientDomainConnect() async throws {
    let transport = AsyncStreamTransport()
    try await transport.start()

    let client = AsyncSocks4ProxyClient(
        transport: transport,
        userId: "user",
        useSocks4a: true,
        timeoutMilliseconds: 5_000
    )

    let connectTask = Task {
        try await client.connect(to: "example.com", port: 110)
    }
    await transport.yieldIncoming([0x00, 0x5A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    _ = try await connectTask.value

    let sent = await transport.sentSnapshot()
    let first = sent.first ?? []
    #expect(first.count > 9)
    #expect(Array(first.prefix(4)) == [0x04, 0x01, 0x00, 0x6E])
    #expect(Array(first[4..<8]) == [0x00, 0x00, 0x00, 0x01])
    #expect(first.contains(0x00))
}
