//
// SmtpCommandKind.swift
//
// SMTP command definitions.
//

public enum SmtpCommandKind: Sendable {
    case helo(String)
    case ehlo(String)
    case mailFrom(String)
    case rcptTo(String)
    case data
    case rset
    case noop
    case quit
    case starttls
    case vrfy(String)
    case expn(String)
    case help(String?)
    case auth(String, initialResponse: String?)

    public func command() -> SmtpCommand {
        switch self {
        case let .helo(domain):
            return SmtpCommand(keyword: "HELO", arguments: domain)
        case let .ehlo(domain):
            return SmtpCommand(keyword: "EHLO", arguments: domain)
        case let .mailFrom(address):
            return SmtpCommand(keyword: "MAIL", arguments: "FROM:<\(address)>")
        case let .rcptTo(address):
            return SmtpCommand(keyword: "RCPT", arguments: "TO:<\(address)>")
        case .data:
            return SmtpCommand(keyword: "DATA")
        case .rset:
            return SmtpCommand(keyword: "RSET")
        case .noop:
            return SmtpCommand(keyword: "NOOP")
        case .quit:
            return SmtpCommand(keyword: "QUIT")
        case .starttls:
            return SmtpCommand(keyword: "STARTTLS")
        case let .vrfy(argument):
            return SmtpCommand(keyword: "VRFY", arguments: argument)
        case let .expn(argument):
            return SmtpCommand(keyword: "EXPN", arguments: argument)
        case let .help(argument):
            if let argument {
                return SmtpCommand(keyword: "HELP", arguments: argument)
            }
            return SmtpCommand(keyword: "HELP")
        case let .auth(mechanism, initialResponse):
            if let response = initialResponse {
                return SmtpCommand(keyword: "AUTH", arguments: "\(mechanism) \(response)")
            }
            return SmtpCommand(keyword: "AUTH", arguments: mechanism)
        }
    }
}
