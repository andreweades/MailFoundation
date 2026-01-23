//
// ProtocolLogger.swift
//
// Ported from MailKit (C#) to Swift.
//

import Foundation

public protocol ProtocolLoggerType: AnyObject {
    var authenticationSecretDetector: AuthenticationSecretDetector? { get set }
    func logConnect(_ uri: URL)
    func logClient(_ buffer: [UInt8], offset: Int, count: Int)
    func logServer(_ buffer: [UInt8], offset: Int, count: Int)
    func close()
}

public typealias IProtocolLogger = ProtocolLoggerType

public enum ProtocolLoggerError: Error, Sendable {
    case invalidArguments
    case unableToOpenStream
    case writeFailed
}

public class ProtocolLogger: ProtocolLoggerType {
    public static let defaultClientPrefix = "C: "
    public static let defaultServerPrefix = "S: "
    private static let secretMaskBytes: [UInt8] = Array("********".utf8)
    private static let spaceBytes: [UInt8] = [0x20]

    public var clientPrefix: String {
        get { String(decoding: clientPrefixBytes, as: UTF8.self) }
        set { clientPrefixBytes = Array(newValue.utf8) }
    }

    public var serverPrefix: String {
        get { String(decoding: serverPrefixBytes, as: UTF8.self) }
        set { serverPrefixBytes = Array(newValue.utf8) }
    }

    public var redactSecrets: Bool = true
    public var logTimestamps: Bool = false
    public var timestampFormat: String = "yyyy-MM-dd'T'HH:mm:ss'Z'"

    public var authenticationSecretDetector: AuthenticationSecretDetector?

    public var stream: OutputStream {
        outputStream
    }

    private var clientPrefixBytes: [UInt8]
    private var serverPrefixBytes: [UInt8]
    private let outputStream: OutputStream
    private let leaveOpen: Bool
    private var clientMidline: Bool = false
    private var serverMidline: Bool = false
    private var isClosed: Bool = false

    public init(fileURL: URL, append: Bool = true) throws {
        guard let stream = OutputStream(url: fileURL, append: append) else {
            throw ProtocolLoggerError.unableToOpenStream
        }
        self.outputStream = stream
        self.leaveOpen = false
        self.clientPrefixBytes = Array(Self.defaultClientPrefix.utf8)
        self.serverPrefixBytes = Array(Self.defaultServerPrefix.utf8)
        stream.open()
        if stream.streamStatus == .error {
            throw ProtocolLoggerError.unableToOpenStream
        }
    }

    public convenience init(filePath: String, append: Bool = true) throws {
        try self.init(fileURL: URL(fileURLWithPath: filePath), append: append)
    }

    public init(stream: OutputStream, leaveOpen: Bool = false) {
        self.outputStream = stream
        self.leaveOpen = leaveOpen
        self.clientPrefixBytes = Array(Self.defaultClientPrefix.utf8)
        self.serverPrefixBytes = Array(Self.defaultServerPrefix.utf8)
        stream.open()
    }

    deinit {
        close()
    }

    public func close() {
        guard !isClosed else { return }
        isClosed = true
        if !leaveOpen {
            outputStream.close()
        }
    }

    public func logConnect(_ uri: URL) {
        var message: String
        if logTimestamps {
            message = "\(formattedTimestamp()) Connected to \(uri.absoluteString)\r\n"
        } else {
            message = "Connected to \(uri.absoluteString)\r\n"
        }

        if clientMidline || serverMidline {
            _ = writeBytes([0x0D, 0x0A])
            clientMidline = false
            serverMidline = false
        }

        _ = writeBytes(Array(message.utf8))
    }

    public func logClient(_ buffer: [UInt8], offset: Int, count: Int) {
        guard validateArguments(buffer, offset: offset, count: count) else {
            return
        }
        log(prefix: clientPrefixBytes, midline: &clientMidline, buffer: buffer, offset: offset, count: count, isClient: true)
    }

    public func logServer(_ buffer: [UInt8], offset: Int, count: Int) {
        guard validateArguments(buffer, offset: offset, count: count) else {
            return
        }
        log(prefix: serverPrefixBytes, midline: &serverMidline, buffer: buffer, offset: offset, count: count, isClient: false)
    }

    private func validateArguments(_ buffer: [UInt8], offset: Int, count: Int) -> Bool {
        guard offset >= 0, offset <= buffer.count else { return false }
        guard count >= 0, count <= (buffer.count - offset) else { return false }
        return true
    }

    private func log(prefix: [UInt8], midline: inout Bool, buffer: [UInt8], offset: Int, count: Int, isClient: Bool) {
        let endIndex = offset + count
        var index = offset

        while index < endIndex {
            var start = index

            while index < endIndex, buffer[index] != 0x0A {
                index += 1
            }

            if !midline {
                if logTimestamps {
                    let timestampBytes = Array(formattedTimestamp().utf8)
                    _ = writeBytes(timestampBytes)
                    _ = writeBytes(Self.spaceBytes)
                }
                _ = writeBytes(prefix)
            }

            if index < endIndex, buffer[index] == 0x0A {
                midline = false
                index += 1
            } else {
                midline = true
            }

            if isClient, redactSecrets, let detector = authenticationSecretDetector {
                let secrets = detector.detectSecrets(in: buffer, offset: start, count: index - start)
                for secret in secrets {
                    if secret.startIndex > start {
                        _ = writeBytes(Array(buffer[start..<secret.startIndex]))
                    }
                    start = secret.startIndex + secret.length
                    _ = writeBytes(Self.secretMaskBytes)
                }
            }

            if start < index {
                _ = writeBytes(Array(buffer[start..<index]))
            }
        }
    }

    private func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = timestampFormat
        return formatter.string(from: Date())
    }

    @discardableResult
    private func writeBytes(_ bytes: [UInt8]) -> Bool {
        guard !bytes.isEmpty else { return true }
        var totalWritten = 0
        while totalWritten < bytes.count {
            let written = bytes.withUnsafeBytes { pointer -> Int in
                guard let base = pointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return -1
                }
                let start = base.advanced(by: totalWritten)
                return outputStream.write(start, maxLength: bytes.count - totalWritten)
            }

            if written <= 0 {
                return false
            }

            totalWritten += written
        }
        return true
    }
}
