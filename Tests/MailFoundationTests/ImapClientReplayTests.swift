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

@Test("IMAP client IDLE not supported (replay)")
func imapClientIdleNotSupportedReplay() {
    let transport = ImapReplayTransport(steps: [
        .command("A0001 IDLE\r\n", fixture: "common/common.idle-not-supported.txt")
    ])

    let client = ImapClient()
    client.connect(transport: transport)

    let command = client.send(.idle)
    let response = client.waitForTagged(command.tag, maxReads: 2)

    #expect(response?.status == .bad)
    #expect(transport.failures.isEmpty)
}

@Test("IMAP client NOTIFY not supported (replay)")
func imapClientNotifyNotSupportedReplay() {
    let transport = ImapReplayTransport(steps: [
        .command("A0001 NOTIFY NONE\r\n", fixture: "common/common.notify-not-supported.txt")
    ])

    let client = ImapClient()
    client.connect(transport: transport)

    let command = client.send(.notify("NONE"))
    let response = client.waitForTagged(command.tag, maxReads: 2)

    #expect(response?.status == .bad)
    #expect(transport.failures.isEmpty)
}

@available(macOS 10.15, iOS 13.0, *)
@Test("Async IMAP client IDLE not supported")
func asyncImapClientIdleNotSupported() async throws {
    let transport = AsyncStreamTransport()
    let client = AsyncImapClient(transport: transport)
    try await client.start()

    let command = try await client.send(.idle)
    let sent = await transport.sentSnapshot()
    #expect(String(decoding: sent.last ?? [], as: UTF8.self).contains("IDLE"))

    await transport.yieldIncoming(Array("\(command.tag) BAD IDLE not supported.\r\n".utf8))
    let response = await client.waitForTagged(command.tag)
    #expect(response?.status == .bad)

    await client.stop()
}

@available(macOS 10.15, iOS 13.0, *)
@Test("Async IMAP client NOTIFY not supported")
func asyncImapClientNotifyNotSupported() async throws {
    let transport = AsyncStreamTransport()
    let client = AsyncImapClient(transport: transport)
    try await client.start()

    let command = try await client.send(.notify("NONE"))
    let sent = await transport.sentSnapshot()
    #expect(String(decoding: sent.last ?? [], as: UTF8.self).contains("NOTIFY"))

    await transport.yieldIncoming(Array("\(command.tag) BAD NOTIFY not supported.\r\n".utf8))
    let response = await client.waitForTagged(command.tag)
    #expect(response?.status == .bad)

    await client.stop()
}
