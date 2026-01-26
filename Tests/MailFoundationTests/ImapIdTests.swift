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

import Testing
@testable import MailFoundation

@Test("IMAP ID response parsing")
func imapIdResponseParsing() {
    let response = ImapIdResponse.parse("* ID (\"name\" \"server\" \"version\" NIL)")
    #expect(response != nil)
    guard let response else { return }
    #expect(response.values["name"] == "server")
    #expect(response.values["version"] == .some(nil))

    let nilResponse = ImapIdResponse.parse("* ID NIL")
    #expect(nilResponse?.values.isEmpty == true)
}

@Test("IMAP ID command serialization")
func imapIdCommandSerialization() {
    let parameters: [String: String?] = [
        "name": "client",
        "version": nil
    ]
    let command = ImapCommandKind.id(parameters).command(tag: "A1").serialized
    #expect(command == "A1 ID (\"name\" \"client\" \"version\" NIL)\r\n")
}

@Test("IMAP session ID command parsing")
func imapSessionIdCommand() throws {
    let transport = TestTransport(incoming: [
        Array("* OK Ready\r\n".utf8),
        Array("* ID (\"name\" \"server\" \"version\" \"1\")\r\n".utf8),
        Array("A0001 OK ID\r\n".utf8)
    ])
    let session = ImapSession(transport: transport, maxReads: 3)
    _ = try session.connect()

    let response = try session.id(["name": "client"])
    #expect(response != nil)
    guard let response else { return }
    #expect(response.values["name"] == "server")
    #expect(response.values["version"] == "1")

    let sent = transport.written.map { String(decoding: $0, as: UTF8.self) }
    #expect(sent.contains("A0001 ID (\"name\" \"client\")\r\n"))
}

@available(macOS 10.15, iOS 13.0, *)
@Test("Async IMAP session ID command parsing")
func asyncImapSessionIdCommand() async throws {
    let transport = AsyncStreamTransport()
    let session = AsyncImapSession(transport: transport)

    let connectTask = Task { try await session.connect() }
    await transport.yieldIncoming(Array("* OK Ready\r\n".utf8))
    _ = try await connectTask.value

    let idTask = Task { try await session.id(["name": "client"]) }
    await transport.yieldIncoming(Array("* ID (\"name\" \"server\" \"version\" \"1\")\r\n".utf8))
    await transport.yieldIncoming(Array("A0001 OK ID\r\n".utf8))
    let response = try await idTask.value

    #expect(response != nil)
    guard let response else { return }
    #expect(response.values["name"] == "server")
    #expect(response.values["version"] == "1")
}
