import Testing
@testable import MailFoundation

@Test("Sync POP3 session LAST and raw bytes")
func syncPop3SessionLastAndRawBytes() throws {
    let rawLine: [UInt8] = [0x66, 0x6f, 0x6f, 0xff]
    let retrChunk = Array("+OK\r\n".utf8) + rawLine + [0x0d, 0x0a] + [0x2e, 0x0d, 0x0a]
    let topChunk = Array("+OK\r\n".utf8) + rawLine + [0x0d, 0x0a] + [0x2e, 0x0d, 0x0a]

    let transport = TestTransport(incoming: [
        Array("+OK Ready\r\n".utf8),
        Array("+OK\r\n".utf8),
        Array("+OK\r\n".utf8),
        Array("+OK 3\r\n".utf8),
        retrChunk,
        topChunk
    ])
    let session = Pop3Session(transport: transport, maxReads: 3)
    _ = try session.connect()
    _ = try session.authenticate(user: "user", password: "pass")
    let last = try session.last()
    #expect(last == 3)
    let retrBytes = try session.retrRaw(1)
    #expect(retrBytes == rawLine)
    let topBytes = try session.topRaw(1, lines: 1)
    #expect(topBytes == rawLine)
}

@Test("Sync POP3 session streaming RETR/TOP")
func syncPop3SessionStreamedData() throws {
    let retrChunk = Array("+OK\r\n".utf8)
        + Array("foo\r\n".utf8)
        + Array("..bar\r\n".utf8)
        + Array(".\r\n".utf8)
    let topChunk = Array("+OK\r\n".utf8)
        + Array("baz\r\n".utf8)
        + Array(".\r\n".utf8)

    let transport = TestTransport(incoming: [
        Array("+OK Ready\r\n".utf8),
        Array("+OK\r\n".utf8),
        Array("+OK\r\n".utf8),
        retrChunk,
        topChunk
    ])
    let session = Pop3Session(transport: transport, maxReads: 3)
    _ = try session.connect()
    _ = try session.authenticate(user: "user", password: "pass")

    var retrBytes: [UInt8] = []
    try session.retrStream(1) { chunk in
        retrBytes.append(contentsOf: chunk)
    }
    #expect(retrBytes == Array("foo\r\n.bar".utf8))

    var topBytes: [UInt8] = []
    try session.topStream(1, lines: 1) { chunk in
        topBytes.append(contentsOf: chunk)
    }
    #expect(topBytes == Array("baz".utf8))
}

@available(macOS 10.15, iOS 13.0, *)
@Test("Async POP3 session LAST and raw bytes")
func asyncPop3SessionLastAndRawBytes() async throws {
    let rawLine: [UInt8] = [0x66, 0x6f, 0x6f, 0xff]
    let retrChunk = Array("+OK\r\n".utf8) + rawLine + [0x0d, 0x0a] + [0x2e, 0x0d, 0x0a]
    let topChunk = Array("+OK\r\n".utf8) + rawLine + [0x0d, 0x0a] + [0x2e, 0x0d, 0x0a]

    let transport = AsyncStreamTransport()
    let session = AsyncPop3Session(transport: transport)

    let connectTask = Task { try await session.connect() }
    await transport.yieldIncoming(Array("+OK Ready\r\n".utf8))
    _ = try await connectTask.value

    let authTask = Task { try await session.authenticate(user: "user", password: "pass") }
    await transport.yieldIncoming(Array("+OK\r\n".utf8))
    await transport.yieldIncoming(Array("+OK\r\n".utf8))
    _ = try await authTask.value

    let lastTask = Task { try await session.last() }
    await transport.yieldIncoming(Array("+OK 3\r\n".utf8))
    let last = try await lastTask.value
    #expect(last == 3)

    let retrTask = Task { try await session.retrRaw(1) }
    await transport.yieldIncoming(retrChunk)
    let retrBytes = try await retrTask.value
    #expect(retrBytes == rawLine)

    let topTask = Task { try await session.topRaw(1, lines: 1) }
    await transport.yieldIncoming(topChunk)
    let topBytes = try await topTask.value
    #expect(topBytes == rawLine)
}

@available(macOS 10.15, iOS 13.0, *)
@Test("Async POP3 session streaming RETR/TOP")
func asyncPop3SessionStreamedData() async throws {
    let retrChunk = Array("+OK\r\n".utf8)
        + Array("foo\r\n".utf8)
        + Array("..bar\r\n".utf8)
        + Array(".\r\n".utf8)
    let topChunk = Array("+OK\r\n".utf8)
        + Array("baz\r\n".utf8)
        + Array(".\r\n".utf8)

    let transport = AsyncStreamTransport()
    let session = AsyncPop3Session(transport: transport)

    let connectTask = Task { try await session.connect() }
    await transport.yieldIncoming(Array("+OK Ready\r\n".utf8))
    _ = try await connectTask.value

    let authTask = Task { try await session.authenticate(user: "user", password: "pass") }
    await transport.yieldIncoming(Array("+OK\r\n".utf8))
    await transport.yieldIncoming(Array("+OK\r\n".utf8))
    _ = try await authTask.value

    let retrCollector = ByteCollector()
    let retrTask = Task {
        try await session.retrStream(1) { chunk in
            await retrCollector.append(chunk)
        }
    }
    await transport.yieldIncoming(retrChunk)
    _ = try await retrTask.value
    let retrBytes = await retrCollector.snapshot()
    #expect(retrBytes == Array("foo\r\n.bar".utf8))

    let topCollector = ByteCollector()
    let topTask = Task {
        try await session.topStream(1, lines: 1) { chunk in
            await topCollector.append(chunk)
        }
    }
    await transport.yieldIncoming(topChunk)
    _ = try await topTask.value
    let topBytes = await topCollector.snapshot()
    #expect(topBytes == Array("baz".utf8))
}

@available(macOS 10.15, iOS 13.0, *)
private actor ByteCollector {
    private var bytes: [UInt8] = []

    func append(_ chunk: [UInt8]) {
        bytes.append(contentsOf: chunk)
    }

    func snapshot() -> [UInt8] {
        bytes
    }
}
