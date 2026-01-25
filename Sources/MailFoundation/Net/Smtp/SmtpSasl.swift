//
// SmtpSasl.swift
//
// SASL helpers for SMTP AUTH.
//

import Foundation

public struct SmtpAuthentication: Sendable {
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

public enum SmtpSasl {
    public static func base64(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
    }

    public static func plain(
        username: String,
        password: String,
        authorizationId: String? = nil
    ) -> SmtpAuthentication {
        let authz = authorizationId ?? ""
        let payload = "\(authz)\u{0}\(username)\u{0}\(password)"
        return SmtpAuthentication(
            mechanism: "PLAIN",
            initialResponse: base64(payload)
        )
    }

    public static func login(
        username: String,
        password: String,
        useInitialResponse: Bool = false
    ) -> SmtpAuthentication {
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
        return SmtpAuthentication(
            mechanism: "LOGIN",
            initialResponse: initial,
            responder: responder
        )
    }

    public static func xoauth2(username: String, accessToken: String) -> SmtpAuthentication {
        let payload = "user=\(username)\u{01}auth=Bearer \(accessToken)\u{01}\u{01}"
        return SmtpAuthentication(
            mechanism: "XOAUTH2",
            initialResponse: base64(payload)
        )
    }
}
