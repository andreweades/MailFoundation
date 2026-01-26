//
// SmtpResponse.swift
//
// Basic SMTP response model and parser.
//

/// Represents a response from an SMTP server.
///
/// SMTP responses consist of a three-digit status code followed by text.
/// Multi-line responses have a hyphen after the code on all lines except the last,
/// which has a space. This type aggregates all lines of a response.
///
/// ## Example
/// ```swift
/// let response = try transport.ehlo(domain: "example.com")
/// if response.isSuccess {
///     print("Server responded: \(response.response)")
/// } else {
///     print("Error \(response.code): \(response.response)")
/// }
/// ```
///
/// ## See Also
/// - ``SmtpStatusCode``
/// - ``SmtpEnhancedStatusCode``
/// - ``SmtpResponseParser``
public struct SmtpResponse: Sendable {
    /// The three-digit SMTP status code.
    ///
    /// The first digit indicates the category:
    /// - 2xx: Success
    /// - 3xx: Intermediate (more input needed)
    /// - 4xx: Transient failure
    /// - 5xx: Permanent failure
    public let code: Int

    /// The text lines of the response.
    ///
    /// For multi-line responses, each line is stored separately.
    /// The status code prefix is stripped from each line.
    public let lines: [String]

    /// The status code as an ``SmtpStatusCode`` value.
    ///
    /// Provides access to well-known status code constants for comparison.
    public var statusCode: SmtpStatusCode {
        SmtpStatusCode(rawValue: code)
    }

    /// The complete response text with lines joined by newlines.
    ///
    /// Useful for displaying the full response message to users or in logs.
    public var response: String {
        lines.joined(separator: "\n")
    }

    /// Whether the response indicates success (2xx or 3xx status code).
    ///
    /// A success response means the command was accepted. Note that 3xx codes
    /// indicate intermediate success where more input is expected.
    public var isSuccess: Bool {
        code >= 200 && code < 400
    }

    /// Whether the response is an intermediate response (1xx status code).
    ///
    /// Intermediate responses indicate that the command was received but
    /// processing is continuing.
    public var isIntermediate: Bool {
        code >= 100 && code < 200
    }

    /// Whether the response indicates an error (4xx or 5xx status code).
    ///
    /// Error responses mean the command was not accepted. A 4xx code indicates
    /// a temporary failure that may succeed if retried later, while 5xx indicates
    /// a permanent failure.
    public var isError: Bool {
        code >= 400
    }
}

/// A stateful parser for SMTP responses.
///
/// SMTP responses can span multiple lines, with each line starting with the
/// same status code. Lines use a hyphen (`-`) after the code for continuation
/// and a space (` `) for the final line. This parser handles the state needed
/// to accumulate multi-line responses.
///
/// ## Example
/// ```swift
/// var parser = SmtpResponseParser()
/// // Parse lines as they arrive
/// if let response = parser.parseLine("250-example.com") {
///     // Response complete
/// }
/// if let response = parser.parseLine("250-SIZE 52428800") {
///     // Still accumulating...
/// }
/// if let response = parser.parseLine("250 HELP") {
///     // Now we have the complete response
///     print("Received \(response.lines.count) lines")
/// }
/// ```
///
/// ## See Also
/// - ``SmtpResponse``
public struct SmtpResponseParser: Sendable {
    /// The status code being accumulated for a multi-line response.
    private var pendingCode: Int?

    /// The lines accumulated so far for a multi-line response.
    private var pendingLines: [String] = []

    /// Creates a new SMTP response parser.
    public init() {}

    /// Parses a single line of SMTP response text.
    ///
    /// For single-line responses, this returns the complete ``SmtpResponse`` immediately.
    /// For multi-line responses, it accumulates lines and returns `nil` until the
    /// final line is received.
    ///
    /// - Parameter line: A single line of SMTP response text (without trailing CRLF).
    /// - Returns: The complete ``SmtpResponse`` if this was the final line, or `nil` if more lines are expected.
    public mutating func parseLine(_ line: String) -> SmtpResponse? {
        guard line.count >= 4 else {
            resetPendingIfNeeded()
            return nil
        }

        let codeStart = line.startIndex
        let codeEnd = line.index(codeStart, offsetBy: 3)
        let codeText = String(line[codeStart..<codeEnd])
        guard let code = Int(codeText) else {
            resetPendingIfNeeded()
            return nil
        }

        let separatorIndex = codeEnd
        guard separatorIndex < line.endIndex else {
            resetPendingIfNeeded()
            return nil
        }
        let remainderStart = line.index(after: separatorIndex)
        let separator = line[separatorIndex]
        let remainder = remainderStart <= line.endIndex ? String(line[remainderStart...]) : ""

        if let pendingCode, pendingCode != code {
            // Drop invalid mixed-code multiline state and treat this as a new response.
            self.pendingCode = nil
            pendingLines.removeAll(keepingCapacity: true)
        }
        if pendingCode == nil {
            pendingCode = code
        }

        pendingLines.append(remainder)

        if separator == "-" {
            return nil
        }

        let response = SmtpResponse(code: pendingCode ?? code, lines: pendingLines)
        pendingCode = nil
        pendingLines.removeAll(keepingCapacity: true)
        return response
    }

    /// Resets the parser state if a multi-line response was in progress.
    private mutating func resetPendingIfNeeded() {
        guard pendingCode != nil else { return }
        pendingCode = nil
        pendingLines.removeAll(keepingCapacity: true)
    }
}
