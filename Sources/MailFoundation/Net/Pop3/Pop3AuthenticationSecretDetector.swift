//
// Pop3AuthenticationSecretDetector.swift
//
// Ported from MailKit (C#) to Swift.
//

final class Pop3AuthenticationSecretDetector: AuthenticationSecretDetector {
    private enum Pop3AuthCommandState: Int {
        case none
        case a
        case apop
        case apopUserName
        case apopToken
        case apopNewLine
        case auth
        case authMechanism
        case authNewLine
        case authToken
        case user
        case userName
        case userNewLine
        case pass
        case password
        case passNewLine
        case error
    }

    private static let emptySecrets: [AuthenticationSecret] = []

    private var state: Pop3AuthCommandState = .none
    private var authenticating: Bool = false
    private var commandIndex: Int = 0

    var isAuthenticating: Bool {
        get { authenticating }
        set {
            state = .none
            authenticating = newValue
            commandIndex = 0
        }
    }

    private func skipCommand(_ command: [UInt8], buffer: [UInt8], index: inout Int, endIndex: Int) -> Bool {
        while index < endIndex && commandIndex < command.count {
            if buffer[index] != command[commandIndex] {
                state = .error
                break
            }
            commandIndex += 1
            index += 1
        }
        return commandIndex == command.count
    }

    private func detectApopSecrets(buffer: [UInt8], offset: Int, endIndex: Int) -> [AuthenticationSecret] {
        if state == .apopNewLine {
            return Self.emptySecrets
        }

        var secrets: [AuthenticationSecret] = []
        var index = offset

        if state == .apop {
            if skipCommand(Array("APOP ".utf8), buffer: buffer, index: &index, endIndex: endIndex) {
                state = .apopUserName
            }

            if index >= endIndex || state == .error {
                return Self.emptySecrets
            }
        }

        if state == .apopUserName {
            let startIndex = index
            while index < endIndex, buffer[index] != 0x20 {
                index += 1
            }
            if index > startIndex {
                secrets.append(AuthenticationSecret(startIndex: startIndex, length: index - startIndex))
            }
            if index < endIndex {
                state = .apopToken
                index += 1
            }
            if index >= endIndex {
                return secrets
            }
        }

        let startIndex = index
        while index < endIndex, buffer[index] != 0x0D {
            index += 1
        }
        if index < endIndex {
            state = .apopNewLine
        }
        if index > startIndex {
            secrets.append(AuthenticationSecret(startIndex: startIndex, length: index - startIndex))
        }
        return secrets
    }

    private func detectAuthSecrets(buffer: [UInt8], offset: Int, endIndex: Int) -> [AuthenticationSecret] {
        var index = offset

        if state == .auth {
            if skipCommand(Array("AUTH ".utf8), buffer: buffer, index: &index, endIndex: endIndex) {
                state = .authMechanism
            }
            if index >= endIndex || state == .error {
                return Self.emptySecrets
            }
        }

        if state == .authMechanism {
            while index < endIndex, buffer[index] != 0x20, buffer[index] != 0x0D {
                index += 1
            }

            if index < endIndex {
                if buffer[index] == 0x20 {
                    state = .authToken
                } else {
                    state = .authNewLine
                }
                index += 1
            }

            if index >= endIndex {
                return Self.emptySecrets
            }
        }

        if state == .authNewLine {
            if buffer[index] == 0x0A {
                state = .authToken
                index += 1
            } else {
                state = .error
            }

            if index >= endIndex || state == .error {
                return Self.emptySecrets
            }
        }

        let startIndex = index
        while index < endIndex, buffer[index] != 0x0D {
            index += 1
        }

        if index < endIndex {
            state = .authNewLine
        }

        if index == startIndex {
            return Self.emptySecrets
        }

        let secret = AuthenticationSecret(startIndex: startIndex, length: index - startIndex)

        if state == .authNewLine {
            index += 1
            if index < endIndex {
                if buffer[index] == 0x0A {
                    state = .authToken
                } else {
                    state = .error
                }
            }
        }

        return [secret]
    }

    private func detectUserPassSecrets(buffer: [UInt8], offset: Int, endIndex: Int) -> [AuthenticationSecret] {
        var secrets: [AuthenticationSecret] = []
        var index = offset

        if state == .user {
            if skipCommand(Array("USER ".utf8), buffer: buffer, index: &index, endIndex: endIndex) {
                state = .userName
            }
            if index >= endIndex || state == .error {
                return Self.emptySecrets
            }
        }

        if state == .userName {
            let startIndex = index
            while index < endIndex, buffer[index] != 0x0D {
                index += 1
            }
            if index > startIndex {
                secrets.append(AuthenticationSecret(startIndex: startIndex, length: index - startIndex))
            }
            if index < endIndex {
                state = .userNewLine
                index += 1
            }
            if index >= endIndex {
                return secrets
            }
        }

        if state == .userNewLine {
            if buffer[index] == 0x0A {
                state = .pass
                commandIndex = 0
                index += 1
            } else {
                state = .error
            }

            if index >= endIndex || state == .error {
                return secrets
            }
        }

        if state == .pass {
            if skipCommand(Array("PASS ".utf8), buffer: buffer, index: &index, endIndex: endIndex) {
                state = .password
            }
            if index >= endIndex || state == .error {
                return Self.emptySecrets
            }
        }

        if state == .password {
            let startIndex = index
            while index < endIndex, buffer[index] != 0x0D {
                index += 1
            }
            if index > startIndex {
                secrets.append(AuthenticationSecret(startIndex: startIndex, length: index - startIndex))
            }
            if index < endIndex {
                state = .passNewLine
                index += 1
            }
            if index >= endIndex {
                return secrets
            }
        }

        if state == .passNewLine {
            if buffer[index] == 0x0A {
                state = .none
                commandIndex = 0
                index += 1
            } else {
                state = .error
            }
        }

        return secrets
    }

    func detectSecrets(in buffer: [UInt8], offset: Int, count: Int) -> [AuthenticationSecret] {
        guard isAuthenticating, state != .error, count > 0 else {
            return Self.emptySecrets
        }

        let endIndex = offset + count
        var index = offset

        if state == .none {
            switch buffer[index] {
            case 0x41: // A
                state = .a
                index += 1
            case 0x55: // U
                state = .user
                commandIndex = 1
                index += 1
            default:
                state = .error
            }

            if index >= endIndex || state == .error {
                return Self.emptySecrets
            }
        }

        if state == .a {
            switch buffer[index] {
            case 0x50: // P
                state = .apop
                commandIndex = 2
                index += 1
            case 0x55: // U
                state = .auth
                commandIndex = 2
                index += 1
            default:
                state = .error
            }

            if index >= endIndex || state == .error {
                return Self.emptySecrets
            }
        }

        if state.rawValue >= Pop3AuthCommandState.apop.rawValue && state.rawValue <= Pop3AuthCommandState.apopNewLine.rawValue {
            return detectApopSecrets(buffer: buffer, offset: index, endIndex: endIndex)
        }

        if state.rawValue >= Pop3AuthCommandState.auth.rawValue && state.rawValue <= Pop3AuthCommandState.authToken.rawValue {
            return detectAuthSecrets(buffer: buffer, offset: index, endIndex: endIndex)
        }

        return detectUserPassSecrets(buffer: buffer, offset: index, endIndex: endIndex)
    }
}
