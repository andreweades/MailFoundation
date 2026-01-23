//
// Pop3Command.swift
//
// Basic POP3 command model.
//

public struct Pop3Command: Sendable {
    public let keyword: String
    public let arguments: String?

    public init(keyword: String, arguments: String? = nil) {
        self.keyword = keyword
        self.arguments = arguments
    }

    public var serialized: String {
        if let arguments {
            return "\(keyword) \(arguments)\r\n"
        }
        return "\(keyword)\r\n"
    }
}
