//
// SaslMechanism.swift
//
// Unified SASL mechanism interface and common implementations.
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

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
    case cryptoUnavailable
}

// MARK: - Additional Mechanisms

/// The CRAM-MD5 SASL mechanism (RFC 2195).
public struct CramMd5SaslMechanism: SaslMechanism {
    public let name = "CRAM-MD5"
    public let supportsInitialResponse = false

    private let username: String
    private let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    public func initialResponse() throws -> [UInt8]? {
        nil
    }

    public func challenge(_ data: [UInt8]) throws -> [UInt8] {
        guard let digest = hmacMd5Hex(message: Data(data), key: Data(password.utf8)) else {
            throw SaslError.cryptoUnavailable
        }
        let response = "\(username) \(digest)"
        return Array(response.utf8)
    }
}

/// The EXTERNAL SASL mechanism (RFC 4422).
public struct ExternalSaslMechanism: SaslMechanism {
    public let name = "EXTERNAL"
    public let supportsInitialResponse = true

    private let authorizationId: String?

    public init(authorizationId: String? = nil) {
        self.authorizationId = authorizationId
    }

    public func initialResponse() throws -> [UInt8]? {
        Array((authorizationId ?? "").utf8)
    }

    public func challenge(_ data: [UInt8]) throws -> [UInt8] {
        // EXTERNAL typically sends an empty challenge; respond with authzid if needed.
        if data.isEmpty {
            return Array((authorizationId ?? "").utf8)
        }
        throw SaslError.unexpectedChallenge
    }
}

/// The OAUTHBEARER SASL mechanism (RFC 7628).
public struct OAuthBearerSaslMechanism: SaslMechanism {
    public let name = "OAUTHBEARER"
    public let supportsInitialResponse = true

    private let payload: [UInt8]

    /// - Parameters:
    ///   - username: The user identity (used as authzid).
    ///   - accessToken: The OAuth 2.0 bearer token.
    ///   - host: Optional host name.
    ///   - port: Optional port.
    ///   - authorizationId: Optional authorization identity override.
    public init(
        username: String,
        accessToken: String,
        host: String? = nil,
        port: Int? = nil,
        authorizationId: String? = nil
    ) {
        let authz = authorizationId ?? username
        var fields: [String] = []
        if let host {
            fields.append("host=\(host)")
        }
        if let port {
            fields.append("port=\(port)")
        }
        fields.append("auth=Bearer \(accessToken)")

        let gs2Header = "n,a=\(authz),"
        let fieldString = fields.joined(separator: "\u{01}")
        let message = gs2Header + fieldString + "\u{01}\u{01}"
        self.payload = Array(message.utf8)
    }

    public func initialResponse() throws -> [UInt8]? {
        payload
    }

    public func challenge(_ data: [UInt8]) throws -> [UInt8] {
        // Per RFC 7628, challenges indicate errors. We don't auto-reply.
        throw SaslError.unexpectedChallenge
    }
}

/// The DIGEST-MD5 SASL mechanism (RFC 2831).
public final class DigestMd5SaslMechanism: SaslMechanism, @unchecked Sendable {
    public let name = "DIGEST-MD5"
    public let supportsInitialResponse = false

    private enum State {
        case auth
        case final
        case complete
    }

    private let username: String
    private let password: String
    private let authorizationId: String?
    private let host: String
    private let service: String
    private var state: State = .auth
    private var response: DigestMd5Response?
    private var encoding: String.Encoding = .isoLatin1

    public init(
        username: String,
        password: String,
        host: String,
        service: String = "imap",
        authorizationId: String? = nil
    ) {
        self.username = username
        self.password = password
        self.host = host
        self.service = service
        self.authorizationId = authorizationId
    }

    public func initialResponse() throws -> [UInt8]? {
        nil
    }

    public func challenge(_ data: [UInt8]) throws -> [UInt8] {
        guard md5Available else { throw SaslError.cryptoUnavailable }
        switch state {
        case .auth:
            guard !data.isEmpty else { throw SaslError.invalidChallenge }
            guard let challengeText = String(data: Data(data), encoding: .utf8) ??
                    String(data: Data(data), encoding: .isoLatin1) else {
                throw SaslError.invalidChallenge
            }

            let challenge = try DigestMd5Challenge.parse(challengeText)
            encoding = challenge.charset != nil ? .utf8 : .isoLatin1
            let cnonce = generateEntropy(15)
            let response = DigestMd5Response(
                challenge: challenge,
                encoding: encoding,
                service: service,
                host: host,
                authorizationId: authorizationId,
                username: username,
                password: password,
                cnonce: cnonce
            )
            self.response = response
            state = .final
            return response.encode(encoding: encoding)
        case .final:
            guard let response else { throw SaslError.invalidChallenge }
            guard let text = String(data: Data(data), encoding: encoding) else {
                throw SaslError.invalidChallenge
            }
            guard let pair = DigestMd5Challenge.parseSinglePair(text) else {
                throw SaslError.invalidChallenge
            }
            guard pair.key.lowercased() == "rspauth" else {
                throw SaslError.invalidChallenge
            }
            let expected = response.computeHash(encoding: encoding, password: password, client: false)
            guard pair.value == expected else {
                throw SaslError.invalidChallenge
            }
            state = .complete
            return []
        case .complete:
            throw SaslError.unexpectedChallenge
        }
    }
}

private struct DigestMd5Challenge {
    var realms: [String] = []
    var nonce: String?
    var qop: Set<String> = []
    var stale: Bool?
    var maxbuf: Int?
    var charset: String?
    var algorithm: String?
    var ciphers: Set<String> = []

    static func parse(_ token: String) throws -> DigestMd5Challenge {
        var challenge = DigestMd5Challenge()
        var index = token.startIndex

        func skipWhitespace() {
            while index < token.endIndex, token[index].isWhitespace {
                index = token.index(after: index)
            }
        }

        func parseKey() -> String {
            let start = index
            while index < token.endIndex {
                let ch = token[index]
                if ch.isWhitespace || ch == "=" || ch == "," { break }
                index = token.index(after: index)
            }
            return String(token[start..<index])
        }

        func parseQuoted() throws -> String {
            // Assume current is quote
            index = token.index(after: index)
            var result = ""
            var escaped = false
            while index < token.endIndex {
                let ch = token[index]
                if ch == "\\" {
                    escaped.toggle()
                    if escaped {
                        index = token.index(after: index)
                        continue
                    }
                }
                if !escaped, ch == "\"" {
                    break
                }
                result.append(ch)
                escaped = false
                index = token.index(after: index)
            }
            guard index < token.endIndex, token[index] == "\"" else {
                throw SaslError.invalidChallenge
            }
            index = token.index(after: index)
            return result
        }

        func parseValue() throws -> String {
            if index < token.endIndex, token[index] == "\"" {
                return try parseQuoted()
            }
            let start = index
            while index < token.endIndex {
                let ch = token[index]
                if ch.isWhitespace || ch == "," { break }
                index = token.index(after: index)
            }
            return String(token[start..<index])
        }

        skipWhitespace()
        while index < token.endIndex {
            let key = parseKey()
            skipWhitespace()
            guard index < token.endIndex, token[index] == "=" else {
                throw SaslError.invalidChallenge
            }
            index = token.index(after: index)
            skipWhitespace()
            guard index < token.endIndex else { throw SaslError.invalidChallenge }
            let value = try parseValue()

            switch key.lowercased() {
            case "realm":
                challenge.realms = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            case "nonce":
                challenge.nonce = value
            case "qop":
                for item in value.split(separator: ",") {
                    challenge.qop.insert(item.trimmingCharacters(in: .whitespaces))
                }
            case "stale":
                challenge.stale = value.caseInsensitiveCompare("true") == .orderedSame
            case "maxbuf":
                challenge.maxbuf = Int(value)
            case "charset":
                if value.lowercased() != "utf-8" {
                    throw SaslError.invalidChallenge
                }
                challenge.charset = value
            case "algorithm":
                challenge.algorithm = value
            case "cipher":
                for item in value.split(separator: ",") {
                    challenge.ciphers.insert(item.trimmingCharacters(in: .whitespaces))
                }
            default:
                break
            }

            skipWhitespace()
            if index < token.endIndex, token[index] == "," {
                index = token.index(after: index)
                skipWhitespace()
            }
        }

        guard challenge.nonce != nil else { throw SaslError.invalidChallenge }
        return challenge
    }

    static func parseSinglePair(_ token: String) -> (key: String, value: String)? {
        var index = token.startIndex

        func skipWhitespace() {
            while index < token.endIndex, token[index].isWhitespace {
                index = token.index(after: index)
            }
        }

        func parseKey() -> String {
            let start = index
            while index < token.endIndex {
                let ch = token[index]
                if ch.isWhitespace || ch == "=" || ch == "," { break }
                index = token.index(after: index)
            }
            return String(token[start..<index])
        }

        func parseQuoted() -> String? {
            index = token.index(after: index)
            var result = ""
            var escaped = false
            while index < token.endIndex {
                let ch = token[index]
                if ch == "\\" {
                    escaped.toggle()
                    if escaped {
                        index = token.index(after: index)
                        continue
                    }
                }
                if !escaped, ch == "\"" {
                    break
                }
                result.append(ch)
                escaped = false
                index = token.index(after: index)
            }
            guard index < token.endIndex, token[index] == "\"" else { return nil }
            index = token.index(after: index)
            return result
        }

        func parseValue() -> String? {
            if index < token.endIndex, token[index] == "\"" {
                return parseQuoted()
            }
            let start = index
            while index < token.endIndex {
                let ch = token[index]
                if ch.isWhitespace || ch == "," { break }
                index = token.index(after: index)
            }
            return String(token[start..<index])
        }

        skipWhitespace()
        guard index < token.endIndex else { return nil }
        let key = parseKey()
        skipWhitespace()
        guard index < token.endIndex, token[index] == "=" else { return nil }
        index = token.index(after: index)
        skipWhitespace()
        guard let value = parseValue() else { return nil }
        return (key, value)
    }
}

private struct DigestMd5Response {
    let username: String
    let realm: String
    let nonce: String
    let cnonce: String
    let nc: Int
    let qop: String
    let digestUri: String
    let response: String  // computed during init
    let maxbuf: Int?
    let charset: String?
    let algorithm: String?
    let cipher: String?
    let authzid: String?

    init(
        challenge: DigestMd5Challenge,
        encoding: String.Encoding,
        service: String,
        host: String,
        authorizationId: String?,
        username: String,
        password: String,
        cnonce: String
    ) {
        self.username = username
        self.realm = challenge.realms.first ?? ""
        self.nonce = challenge.nonce ?? ""
        self.cnonce = cnonce
        self.nc = 1
        self.qop = challenge.qop.contains("auth") ? "auth" : (challenge.qop.first ?? "auth")
        self.digestUri = "\(service)/\(host)"
        self.algorithm = challenge.algorithm
        self.charset = challenge.charset
        self.maxbuf = challenge.maxbuf
        self.authzid = authorizationId
        self.cipher = nil
        // Compute response using static helper since we can't call instance methods yet
        self.response = Self.computeHashStatic(
            encoding: encoding,
            password: password,
            client: true,
            username: username,
            realm: self.realm,
            nonce: self.nonce,
            cnonce: cnonce,
            nc: 1,
            qop: self.qop,
            digestUri: self.digestUri,
            authzid: authorizationId
        )
    }

    private static func computeHashStatic(
        encoding: String.Encoding,
        password: String,
        client: Bool,
        username: String,
        realm: String,
        nonce: String,
        cnonce: String,
        nc: Int,
        qop: String,
        digestUri: String,
        authzid: String?
    ) -> String {
        let a1 = {
            let text = "\(username):\(realm):\(password)"
            let data = stringData(text, encoding: encoding)
            let digest = md5Bytes(data)
            var a1Data = Data(digest)
            var suffix = ":\(nonce):\(cnonce)"
            if let authzid, !authzid.isEmpty {
                suffix += ":\(authzid)"
            }
            a1Data.append(stringData(suffix, encoding: encoding))
            return md5Hex(a1Data)
        }()

        var a2 = client ? "AUTHENTICATE:" : ":"
        a2 += digestUri
        if qop == "auth-int" || qop == "auth-conf" {
            a2 += ":00000000000000000000000000000000"
        }
        let a2Hash = md5Hex(stringData(a2, encoding: encoding))

        let kd = "\(a1):\(nonce):\(String(format: "%08x", nc)):\(cnonce):\(qop):\(a2Hash)"
        return md5Hex(stringData(kd, encoding: encoding))
    }

    func computeHash(encoding: String.Encoding, password: String, client: Bool) -> String {
        Self.computeHashStatic(
            encoding: encoding,
            password: password,
            client: client,
            username: username,
            realm: realm,
            nonce: nonce,
            cnonce: cnonce,
            nc: nc,
            qop: qop,
            digestUri: digestUri,
            authzid: authzid
        )
    }

    func encode(encoding: String.Encoding) -> [UInt8] {
        var builder = ""
        builder.append("username=")
        appendQuoted(&builder, value: username)
        builder.append(",realm=\"\(realm)\"")
        builder.append(",nonce=\"\(nonce)\"")
        builder.append(",cnonce=\"\(cnonce)\"")
        builder.append(String(format: ",nc=%08x", nc))
        builder.append(",qop=\"\(qop)\"")
        builder.append(",digest-uri=\"\(digestUri)\"")
        builder.append(",response=\(response)")
        if let maxbuf {
            builder.append(",maxbuf=\(maxbuf)")
        }
        if let charset, !charset.isEmpty {
            builder.append(",charset=\(charset)")
        }
        if let algorithm, !algorithm.isEmpty {
            builder.append(",algorithm=\(algorithm)")
        }
        if let cipher, !cipher.isEmpty {
            builder.append(",cipher=\"\(cipher)\"")
        }
        if let authzid, !authzid.isEmpty {
            builder.append(",authzid=\"\(authzid)\"")
        }
        return Array(stringData(builder, encoding: encoding))
    }
}

private func appendQuoted(_ builder: inout String, value: String) {
    builder.append("\"")
    for ch in value {
        if ch == "\\" || ch == "\"" {
            builder.append("\\")
        }
        builder.append(ch)
    }
    builder.append("\"")
}

private func stringData(_ text: String, encoding: String.Encoding) -> Data {
    if let data = text.data(using: encoding) {
        return data
    }
    return Data(text.utf8)
}

private func md5Hex(_ data: Data) -> String {
    #if canImport(CryptoKit)
    let digest = Insecure.MD5.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
    #else
    return ""
    #endif
}

private func md5Bytes(_ data: Data) -> [UInt8] {
    #if canImport(CryptoKit)
    return Array(Insecure.MD5.hash(data: data))
    #else
    return []
    #endif
}

private func hmacMd5Hex(message: Data, key: Data) -> String? {
    #if canImport(CryptoKit)
    let mac = HMAC<Insecure.MD5>.authenticationCode(for: message, using: SymmetricKey(data: key))
    return mac.map { String(format: "%02x", $0) }.joined()
    #else
    return nil
    #endif
}

private let md5Available: Bool = {
    #if canImport(CryptoKit)
    return true
    #else
    return false
    #endif
}()

private func generateEntropy(_ count: Int) -> String {
    var bytes = [UInt8](repeating: 0, count: count)
    _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
    return Data(bytes).base64EncodedString()
}
