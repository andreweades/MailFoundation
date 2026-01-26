import Testing
@testable import MailFoundation

struct AsyncImapSessionFailureTests {

    @Test("Async IMAP session throws when selecting without authentication")
    func asyncImapSessionOperationsWithoutAuthentication() async throws {
        let transport = AsyncStreamTransport()
        let session = AsyncImapSession(transport: transport)

        let connectTask = Task { try await session.connect() }
        await transport.yieldIncoming(Array("* OK Ready\r\n".utf8))
        _ = try await connectTask.value

        // Try to select without logging in
        let selectTask = Task { try await session.select(mailbox: "INBOX") }
        
        do {
            _ = try await selectTask.value
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as SessionError {
            if case .invalidImapState(let expected, let actual) = error {
                #expect(expected == .authenticated)
                #expect(actual == .connected)
            } else {
                #expect(Bool(false), "Unexpected error type: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("Async IMAP session throws when searching without selection")
    func asyncImapSessionOperationsWithoutSelection() async throws {
        let transport = AsyncStreamTransport()
        let session = AsyncImapSession(transport: transport)

        let connectTask = Task { try await session.connect() }
        await transport.yieldIncoming(Array("* OK Ready\r\n".utf8))
        _ = try await connectTask.value

        let loginTask = Task { try await session.login(user: "user", password: "pass") }
        await transport.yieldIncoming(Array("A0001 OK LOGIN completed\r\n".utf8))
        _ = try await loginTask.value

        // Try to search without selecting a mailbox
        let searchTask = Task { try await session.search("ALL") }

        do {
            _ = try await searchTask.value
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as SessionError {
            if case .invalidImapState(let expected, let actual) = error {
                #expect(expected == .selected)
                #expect(actual == .authenticated)
            } else {
                #expect(Bool(false), "Unexpected error type: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("Async IMAP session handles SELECT failure")
    func asyncImapSessionSelectFailure() async throws {
        let transport = AsyncStreamTransport()
        let session = AsyncImapSession(transport: transport)

        let connectTask = Task { try await session.connect() }
        await transport.yieldIncoming(Array("* OK Ready\r\n".utf8))
        _ = try await connectTask.value

        let loginTask = Task { try await session.login(user: "user", password: "pass") }
        await transport.yieldIncoming(Array("A0001 OK LOGIN completed\r\n".utf8))
        _ = try await loginTask.value

        let selectTask = Task { try await session.select(mailbox: "NonExistent") }
        await transport.yieldIncoming(Array("A0002 NO [NONEXISTENT] Unknown Mailbox\r\n".utf8))
        
        do {
            _ = try await selectTask.value
            #expect(Bool(false), "Should have thrown an error")
        } catch let error as SessionError {
            if case .imapError(let status, _) = error {
                #expect(status == .no)
            } else {
                #expect(Bool(false), "Unexpected error type: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
        
        #expect(await session.selectedMailbox == nil)
    }

    @Test("Async IMAP session handles protocol error")
    func asyncImapSessionProtocolError() async throws {
        let transport = AsyncStreamTransport()
        let session = AsyncImapSession(transport: transport)

        let connectTask = Task { try await session.connect() }
        await transport.yieldIncoming(Array("* OK Ready\r\n".utf8))
        _ = try await connectTask.value

        let loginTask = Task { try await session.login(user: "user", password: "pass") }
        await transport.yieldIncoming(Array("A0001 BAD Invalid command arguments\r\n".utf8))
        
        // login returns response?, so it might return the BAD response or throw depending on implementation.
        // Checking implementation: 
        // public func login(...) async throws -> ImapResponse? {
        //     let command = try await send(.login(user, password))
        //     let response = await waitForTagged(command.tag)
        //     if response?.status == .ok { state = .authenticated } ...
        //     return response
        // }
        // It returns the response, it doesn't throw for BAD/NO.
        
        let response = try await loginTask.value
        #expect(response?.status == .bad)
        #expect(await session.isAuthenticated == false)
    }
}
