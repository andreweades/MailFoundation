//
// SmtpAuthenticationSecretDetector.swift
//
// Ported from MailKit (C#) to Swift.
//

final class SmtpAuthenticationSecretDetector: AuthenticationSecretDetector {
    private enum SmtpAuthCommandState {
        case auth
        case authMechanism
        case authNewLine
        case authToken
        case error
    }

    private static let emptySecrets: [AuthenticationSecret] = []

    private var state: SmtpAuthCommandState = .auth
    private var authenticating: Bool = false
    private var commandIndex: Int = 0

    var isAuthenticating: Bool {
        get { authenticating }
        set {
            state = .auth
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

    func detectSecrets(in buffer: [UInt8], offset: Int, count: Int) -> [AuthenticationSecret] {
        guard isAuthenticating, state != .error, count > 0 else {
            return Self.emptySecrets
        }

        let endIndex = offset + count
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
}
