//
// ImapAuthenticationSecretDetector.swift
//
// Ported from MailKit (C#) to Swift.
//

final class ImapAuthenticationSecretDetector: AuthenticationSecretDetector {
    private enum ImapAuthCommandState: Int {
        case none
        case command
        case authenticate
        case authMechanism
        case authNewLine
        case authToken
        case login
        case userName
        case password
        case loginNewLine
        case error
    }

    private enum ImapLoginTokenType {
        case none
        case atom
        case qString
        case literal
    }

    private enum ImapLiteralState: Int {
        case none
        case octets
        case plus
        case closeBrace
        case literal
        case complete
    }

    private enum ImapQStringState {
        case none
        case escaped
        case endQuote
        case complete
    }

    private static let emptySecrets: [AuthenticationSecret] = []

    private var commandState: ImapAuthCommandState = .none
    private var literalState: ImapLiteralState = .none
    private var qstringState: ImapQStringState = .none
    private var tokenType: ImapLoginTokenType = .none
    private var authenticating: Bool = false
    private var literalOctets: Int = 0
    private var literalSeen: Int = 0
    private var textIndex: Int = 0

    var isAuthenticating: Bool {
        get { authenticating }
        set {
            commandState = .none
            authenticating = newValue
            clearLoginTokenState()
            textIndex = 0
        }
    }

    private func clearLoginTokenState() {
        literalState = .none
        qstringState = .none
        tokenType = .none
        literalOctets = 0
        literalSeen = 0
    }

    private func skipText(_ text: [UInt8], buffer: [UInt8], index: inout Int, endIndex: Int) -> Bool {
        while index < endIndex && textIndex < text.count {
            if buffer[index] != text[textIndex] {
                commandState = .error
                break
            }
            textIndex += 1
            index += 1
        }
        return textIndex == text.count
    }

    private func detectAuthSecrets(buffer: [UInt8], offset: Int, endIndex: Int) -> [AuthenticationSecret] {
        var index = offset

        if commandState == .authenticate {
            if skipText(Array("AUTHENTICATE ".utf8), buffer: buffer, index: &index, endIndex: endIndex) {
                commandState = .authMechanism
            }

            if index >= endIndex || commandState == .error {
                return Self.emptySecrets
            }
        }

        if commandState == .authMechanism {
            while index < endIndex, buffer[index] != 0x20, buffer[index] != 0x0D {
                index += 1
            }

            if index < endIndex {
                if buffer[index] == 0x20 {
                    commandState = .authToken
                } else {
                    commandState = .authNewLine
                }
                index += 1
            }

            if index >= endIndex {
                return Self.emptySecrets
            }
        }

        if commandState == .authNewLine {
            if buffer[index] == 0x0A {
                commandState = .authToken
                index += 1
            } else {
                commandState = .error
            }

            if index >= endIndex || commandState == .error {
                return Self.emptySecrets
            }
        }

        let startIndex = index
        while index < endIndex, buffer[index] != 0x0D {
            index += 1
        }

        if index < endIndex {
            commandState = .authNewLine
        }

        if index == startIndex {
            return Self.emptySecrets
        }

        let secret = AuthenticationSecret(startIndex: startIndex, length: index - startIndex)

        if commandState == .authNewLine {
            index += 1
            if index < endIndex {
                if buffer[index] == 0x0A {
                    commandState = .authToken
                } else {
                    commandState = .error
                }
            }
        }

        return [secret]
    }

    private func skipLiteralToken(secrets: inout [AuthenticationSecret], buffer: [UInt8], index: inout Int, endIndex: Int, sentinel: UInt8) -> Bool {
        if literalState == .octets {
            while index < endIndex, buffer[index] != 0x2B, buffer[index] != 0x7D {
                let digit = Int(buffer[index] - 0x30)
                literalOctets = (literalOctets * 10) + digit
                index += 1
            }

            if index < endIndex {
                if buffer[index] == 0x2B {
                    literalState = .plus
                    textIndex = 0
                } else {
                    literalState = .closeBrace
                    textIndex = 1
                }
                index += 1
            }

            if index >= endIndex {
                return false
            }
        }

        if literalState.rawValue < ImapLiteralState.literal.rawValue {
            if skipText(Array("}\r\n".utf8), buffer: buffer, index: &index, endIndex: endIndex) {
                literalState = .literal
            }
        }

        if index >= endIndex || commandState == .error {
            return false
        }

        if literalState == .literal {
            let remaining = literalOctets - literalSeen
            let available = endIndex - index
            let skip = min(remaining, available)

            if skip > 0 {
                secrets.append(AuthenticationSecret(startIndex: index, length: skip))
                literalSeen += skip
                index += skip
            }

            if literalSeen == literalOctets {
                literalState = .complete
            }
        }

        if literalState == .complete, index < endIndex, buffer[index] == sentinel {
            index += 1
            return true
        }

        return false
    }

    private func skipLoginToken(secrets: inout [AuthenticationSecret], buffer: [UInt8], index: inout Int, endIndex: Int, sentinel: UInt8) -> Bool {
        if tokenType == .none {
            switch buffer[index] {
            case 0x7B: // {
                literalState = .octets
                tokenType = .literal
                index += 1
            case 0x22: // "
                tokenType = .qString
                index += 1
            default:
                tokenType = .atom
            }
        }

        switch tokenType {
        case .literal:
            return skipLiteralToken(secrets: &secrets, buffer: buffer, index: &index, endIndex: endIndex, sentinel: sentinel)
        case .qString:
            if qstringState != .complete {
                let startIndex = index

                while index < endIndex {
                    if qstringState == .escaped {
                        qstringState = .none
                    } else if buffer[index] == 0x5C {
                        qstringState = .escaped
                    } else if buffer[index] == 0x22 {
                        qstringState = .endQuote
                        break
                    }
                    index += 1
                }

                if index > startIndex {
                    secrets.append(AuthenticationSecret(startIndex: startIndex, length: index - startIndex))
                }

                if qstringState == .endQuote {
                    qstringState = .complete
                    index += 1
                }
            }

            if index >= endIndex {
                return false
            }

            if buffer[index] != sentinel {
                commandState = .error
                return false
            }

            index += 1
            return true
        case .atom:
            let startIndex = index
            while index < endIndex, buffer[index] != sentinel {
                index += 1
            }
            if index > startIndex {
                secrets.append(AuthenticationSecret(startIndex: startIndex, length: index - startIndex))
            }
            if index >= endIndex {
                return false
            }
            index += 1
            return true
        case .none:
            return false
        }
    }

    private func detectLoginSecrets(buffer: [UInt8], offset: Int, endIndex: Int) -> [AuthenticationSecret] {
        var secrets: [AuthenticationSecret] = []
        var index = offset

        if commandState == .loginNewLine {
            return Self.emptySecrets
        }

        if commandState == .login {
            if skipText(Array("LOGIN ".utf8), buffer: buffer, index: &index, endIndex: endIndex) {
                commandState = .userName
            }

            if index >= endIndex || commandState == .error {
                return Self.emptySecrets
            }
        }

        if commandState == .userName {
            if skipLoginToken(secrets: &secrets, buffer: buffer, index: &index, endIndex: endIndex, sentinel: 0x20) {
                commandState = .password
                clearLoginTokenState()
            }

            if index >= endIndex || commandState == .error {
                return secrets
            }
        }

        if commandState == .password {
            if skipLoginToken(secrets: &secrets, buffer: buffer, index: &index, endIndex: endIndex, sentinel: 0x0D) {
                commandState = .loginNewLine
                clearLoginTokenState()
            }
        }

        return secrets
    }

    func detectSecrets(in buffer: [UInt8], offset: Int, count: Int) -> [AuthenticationSecret] {
        guard isAuthenticating, commandState != .error, count > 0 else {
            return Self.emptySecrets
        }

        let endIndex = offset + count
        var index = offset

        if commandState == .none {
            while index < endIndex, buffer[index] != 0x20 {
                index += 1
            }

            if index < endIndex {
                commandState = .command
                index += 1
            }

            if index >= endIndex {
                return Self.emptySecrets
            }
        }

        if commandState == .command {
            switch buffer[index] {
            case 0x41: // A
                commandState = .authenticate
                textIndex = 1
                index += 1
            case 0x4C: // L
                commandState = .login
                textIndex = 1
                index += 1
            default:
                commandState = .error
            }

            if index >= endIndex || commandState == .error {
                return Self.emptySecrets
            }
        }

        if commandState.rawValue >= ImapAuthCommandState.authenticate.rawValue && commandState.rawValue <= ImapAuthCommandState.authToken.rawValue {
            return detectAuthSecrets(buffer: buffer, offset: index, endIndex: endIndex)
        }

        return detectLoginSecrets(buffer: buffer, offset: index, endIndex: endIndex)
    }
}
