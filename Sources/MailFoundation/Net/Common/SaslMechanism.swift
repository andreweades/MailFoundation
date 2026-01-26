//
// SaslMechanism.swift
//
// Unified SASL mechanism interface and common implementations.
//

import Foundation

/// A protocol representing a SASL authentication mechanism.
///
/// Implementations of this protocol handle the client-side logic for
/// specific SASL mechanisms (e.g., PLAIN, SCRAM-SHA-256).
///
/// - Note: Implementations should operate on raw bytes. The protocol
///   handler (SMTP/IMAP/POP3) is responsible for Base64 encoding/decoding.
public protocol SaslMechanism: Sendable {
    /// The IANA-registered mechanism name (e.g., "PLAIN", "CRAM-MD5").
    var name: String { get }

    /// Whether the mechanism supports an initial response sent with the AUTH command.
    var supportsInitialResponse: Bool { get }

    /// Generates the initial client response.
    ///
    /// - Returns: The initial response bytes, or nil if not applicable.
    func initialResponse() throws -> [UInt8]?

    /// Processes a server challenge and generates a response.
    ///
    /// - Parameter challenge: The challenge data received from the server.
    /// - Returns: The response data to send to the server.
    /// - Throws: An error if the challenge is invalid or processing fails.
    func challenge(_ data: [UInt8]) throws -> [UInt8]
}

// MARK: - Common Implementations

/// The PLAIN SASL mechanism (RFC 4616).
public struct PlainSaslMechanism: SaslMechanism {
    public let name = "PLAIN"
    public let supportsInitialResponse = true

    private let payload: [UInt8]

    public init(username: String, password: String, authorizationId: String? = nil) {
        let authz = authorizationId ?? ""
        let str = "\(authz)\u{0}\(username)\u{0}\(password)"
        self.payload = Array(str.utf8)
    }

    public func initialResponse() throws -> [UInt8]? {
        payload
    }

    public func challenge(_ data: [UInt8]) throws -> [UInt8] {
        // PLAIN usually doesn't have a challenge flow if initial response is accepted,
        // but if the server sends an empty challenge (continuation), we might resend or fail.
        // Typically, we just return the payload if we haven't sent it yet, but
        // strictly speaking PLAIN is one-shot.
        if data.isEmpty {
            return payload
        }
        throw SaslError.unexpectedChallenge
    }
}

/// The LOGIN SASL mechanism (Draft).
public final class LoginSaslMechanism: SaslMechanism, @unchecked Sendable {
    public let name = "LOGIN"
    public let supportsInitialResponse = true // Can send username initially

    private let username: [UInt8]
    private let password: [UInt8]
    private var state: State = .username

    private enum State {
        case username
        case password
        case complete
    }

    public init(username: String, password: String) {
        self.username = Array(username.utf8)
        self.password = Array(password.utf8)
    }

    public func initialResponse() throws -> [UInt8]? {
        // Some servers accept username as initial response
        state = .password
        return username
    }

    public func challenge(_ data: [UInt8]) throws -> [UInt8] {
        // Determine what the server is asking for based on state or prompt text
        // (Text logic is brittle, state machine is better if protocol flow is fixed)
        
        switch state {
        case .username:
            state = .password
            return username
        case .password:
            state = .complete
            return password
        case .complete:
            throw SaslError.unexpectedChallenge
        }
    }
}

/// The XOAUTH2 SASL mechanism.
public struct XOAuth2SaslMechanism: SaslMechanism {
    public let name = "XOAUTH2"
    public let supportsInitialResponse = true

    private let payload: [UInt8]

    public init(username: String, accessToken: String) {
        let str = "user=\(username)\u{01}auth=Bearer \(accessToken)\u{01}\u{01}"
        self.payload = Array(str.utf8)
    }

    public func initialResponse() throws -> [UInt8]? {
        payload
    }

    public func challenge(_ data: [UInt8]) throws -> [UInt8] {
        // XOAUTH2 error responses come as challenges. 
        // We generally shouldn't reply to an error with a normal token, but
        // if we are here, we might need to handle it.
        // For simple usage, we just treat any challenge as unexpected for now.
        throw SaslError.unexpectedChallenge
    }
}

public enum SaslError: Error {
    case unexpectedChallenge
    case invalidChallenge
    case mechanismNotSupported
}
