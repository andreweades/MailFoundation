//
// Pop3Apop.swift
//
// APOP digest helpers.
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public enum Pop3Apop {
    public static var isAvailable: Bool {
        #if canImport(CryptoKit)
        return true
        #else
        return false
        #endif
    }

    public static func digest(challenge: String, password: String) -> String? {
        #if canImport(CryptoKit)
        let trimmedChallenge = challenge.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = trimmedChallenge + password
        let digest = Insecure.MD5.hash(data: Data(combined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        return nil
        #endif
    }
}

public extension Pop3Response {
    func apopDigest(password: String) -> String? {
        guard let challenge = apopChallenge else { return nil }
        return Pop3Apop.digest(challenge: challenge, password: password)
    }
}
