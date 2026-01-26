//
// Pop3Sasl.swift
//
// SASL helpers for POP3 AUTH.
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public struct Pop3Authentication: Sendable {
    public let mechanism: String
    public let initialResponse: String?
    public let responder: (@Sendable (String) throws -> String)?

    public init(
        mechanism: String,
        initialResponse: String? = nil,
        responder: (@Sendable (String) throws -> String)? = nil
    ) {
        self.mechanism = mechanism
        self.initialResponse = initialResponse
        self.responder = responder
    }
}

public enum Pop3Sasl {
    public static func base64(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
    }

    public static func plain(
        username: String,
        password: String,
        authorizationId: String? = nil
    ) -> Pop3Authentication {
        let authz = authorizationId ?? ""
        let payload = "\(authz)\u{0}\(username)\u{0}\(password)"
        return Pop3Authentication(
            mechanism: "PLAIN",
            initialResponse: base64(payload)
        )
    }

    public static func login(
        username: String,
        password: String,
        useInitialResponse: Bool = false
    ) -> Pop3Authentication {
        let initial = useInitialResponse ? base64(username) : nil
        let responder: @Sendable (String) throws -> String = { challenge in
            let trimmed = challenge.trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = Data(base64Encoded: trimmed),
               let text = String(data: data, encoding: .utf8) {
                let lower = text.lowercased()
                if lower.contains("username") {
                    return base64(username)
                }
                if lower.contains("password") {
                    return base64(password)
                }
            }
            if trimmed.isEmpty {
                return base64(username)
            }
            return base64(password)
        }
        return Pop3Authentication(
            mechanism: "LOGIN",
            initialResponse: initial,
            responder: responder
        )
    }

    public static func cramMd5(
        username: String,
        password: String
    ) -> Pop3Authentication? {
        guard hmacMd5Available else { return nil }
        let responder: @Sendable (String) throws -> String = { challenge in
            let trimmed = challenge.trimmingCharacters(in: .whitespacesAndNewlines)
            let challengeData = Data(base64Encoded: trimmed) ?? Data(trimmed.utf8)
            guard let digest = hmacMd5Hex(message: challengeData, key: Data(password.utf8)) else {
                throw Pop3SaslError.cryptoUnavailable
            }
            let response = "\(username) \(digest)"
            return base64(response)
        }
        return Pop3Authentication(
            mechanism: "CRAM-MD5",
            initialResponse: nil,
            responder: responder
        )
    }

    public static func xoauth2(username: String, accessToken: String) -> Pop3Authentication {
        let payload = "user=\(username)\u{01}auth=Bearer \(accessToken)\u{01}\u{01}"
        return Pop3Authentication(
            mechanism: "XOAUTH2",
            initialResponse: base64(payload)
        )
    }

    public static func chooseAuthentication(
        username: String,
        password: String,
        mechanisms: [String]
    ) -> Pop3Authentication? {
        let normalized = mechanisms.map { $0.uppercased() }
        if normalized.contains("CRAM-MD5"), let cram = cramMd5(username: username, password: password) {
            return cram
        }
        if normalized.contains("PLAIN") {
            return plain(username: username, password: password)
        }
        if normalized.contains("LOGIN") {
            return login(username: username, password: password)
        }
        return nil
    }
}

public enum Pop3SaslError: Error, Sendable, Equatable {
    case cryptoUnavailable
}

private let hmacMd5Available: Bool = {
    #if canImport(CryptoKit)
    return true
    #else
    return false
    #endif
}()

private func hmacMd5Hex(message: Data, key: Data) -> String? {
    #if canImport(CryptoKit)
    let mac = HMAC<Insecure.MD5>.authenticationCode(for: message, using: SymmetricKey(data: key))
    return mac.map { String(format: "%02x", $0) }.joined()
    #else
    return nil
    #endif
}
