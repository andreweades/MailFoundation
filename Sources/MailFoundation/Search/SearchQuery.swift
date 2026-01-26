//
// SearchQuery.swift
//
// Basic IMAP search query builder.
//

import Foundation

/// A specialized query for searching messages in an IMAP mail folder.
///
/// `SearchQuery` provides a type-safe, composable API for building IMAP SEARCH commands.
/// Queries can match messages based on flags, headers, dates, sizes, and other attributes,
/// and can be combined using logical operators.
///
/// ## Overview
///
/// Use `SearchQuery` to find messages that match specific criteria. The query is
/// serialized to IMAP SEARCH syntax when executed against a mail folder.
///
/// ```swift
/// // Find unread messages from a specific sender
/// let query = SearchQuery.from("alice@example.com").and(.unseen)
///
/// // Find messages with "urgent" in the subject, sent in the last week
/// let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
/// let urgentQuery = SearchQuery.subject("urgent").and(.since(weekAgo))
///
/// // Find large messages that are either flagged or unread
/// let largeImportant = SearchQuery.larger(1_000_000)
///     .and(.or(.flagged, .unseen))
/// ```
///
/// ## Building Queries
///
/// Queries can be built using:
/// - Static properties for flag-based queries (``all``, ``seen``, ``flagged``, etc.)
/// - Static methods for parameterized queries (``from(_:)``, ``subject(_:)``, ``since(_:)``, etc.)
/// - Instance methods for combining queries (``and(_:)-9qojv``, ``or(_:)``, ``not()``)
///
/// ## Query Optimization
///
/// Before serialization, queries can be optimized to remove redundant terms:
///
/// ```swift
/// // Redundant terms are simplified
/// let query = SearchQuery.and([.all, .from("bob@example.com"), .all])
/// let optimized = query.optimized()
/// // Result: just .from("bob@example.com")
/// ```
///
/// ## IMAP Compatibility
///
/// The query terms correspond to IMAP SEARCH keys as defined in:
/// - [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4) - IMAP4rev1
/// - [RFC 4551](https://datatracker.ietf.org/doc/html/rfc4551) - CONDSTORE extension
/// - [RFC 5032](https://datatracker.ietf.org/doc/html/rfc5032) - WITHIN extension
///
/// ## See Also
/// - ``Term``
/// - ``SearchQueryOptimizer``
/// - ``OrderBy``
public struct SearchQuery: Sendable, CustomStringConvertible {
    /// The search term types that can be used to match messages.
    ///
    /// `Term` is an indirect enum that represents all possible search criteria.
    /// Terms can be simple (matching a flag or attribute) or compound (combining
    /// other terms with logical operators).
    ///
    /// ## Flag Terms
    ///
    /// These terms match messages based on their IMAP flags:
    ///
    /// | Term | Matches messages with... | IMAP Key |
    /// | --- | --- | --- |
    /// | ``all`` | All messages | `ALL` |
    /// | ``answered`` | `\Answered` flag | `ANSWERED` |
    /// | ``deleted`` | `\Deleted` flag | `DELETED` |
    /// | ``flagged`` | `\Flagged` flag | `FLAGGED` |
    /// | ``seen`` | `\Seen` flag | `SEEN` |
    /// | ``draft`` | `\Draft` flag | `DRAFT` |
    /// | ``recent`` | `\Recent` flag | `RECENT` |
    /// | ``new`` | `\Recent` but not `\Seen` | `NEW` |
    /// | ``old`` | No `\Recent` flag | `OLD` |
    /// | ``unseen`` | No `\Seen` flag | `UNSEEN` |
    /// | ``unanswered`` | No `\Answered` flag | `UNANSWERED` |
    /// | ``undraft`` | No `\Draft` flag | `UNDRAFT` |
    ///
    /// ## Header Terms
    ///
    /// These terms match messages based on header content:
    ///
    /// | Term | Matches | IMAP Key |
    /// | --- | --- | --- |
    /// | ``from(_:)`` | From header contains text | `FROM` |
    /// | ``to(_:)`` | To header contains text | `TO` |
    /// | ``cc(_:)`` | Cc header contains text | `CC` |
    /// | ``bcc(_:)`` | Bcc header contains text | `BCC` |
    /// | ``subject(_:)`` | Subject header contains text | `SUBJECT` |
    /// | ``header(_:_:)`` | Named header contains text | `HEADER` |
    ///
    /// ## Content Terms
    ///
    /// | Term | Matches | IMAP Key |
    /// | --- | --- | --- |
    /// | ``body(_:)`` | Message body contains text | `BODY` |
    /// | ``text(_:)`` | Header or body contains text | `TEXT` |
    ///
    /// ## Date Terms
    ///
    /// | Term | Matches | IMAP Key |
    /// | --- | --- | --- |
    /// | ``on(_:)`` | Delivered on date | `ON` |
    /// | ``since(_:)`` | Delivered after date | `SINCE` |
    /// | ``before(_:)`` | Delivered before date | `BEFORE` |
    /// | ``sentOn(_:)`` | Sent on date | `SENTON` |
    /// | ``sentSince(_:)`` | Sent after date | `SENTSINCE` |
    /// | ``sentBefore(_:)`` | Sent before date | `SENTBEFORE` |
    ///
    /// ## Size Terms
    ///
    /// | Term | Matches | IMAP Key |
    /// | --- | --- | --- |
    /// | ``larger(_:)`` | Size greater than N octets | `LARGER` |
    /// | ``smaller(_:)`` | Size less than N octets | `SMALLER` |
    ///
    /// ## Other Terms
    ///
    /// | Term | Matches | IMAP Key |
    /// | --- | --- | --- |
    /// | ``keyword(_:)`` | Has keyword set | `KEYWORD` |
    /// | ``unkeyword(_:)`` | Does not have keyword | `UNKEYWORD` |
    /// | ``uid(_:)`` | Specific UIDs | `UID` |
    /// | ``raw(_:)`` | Raw IMAP search text | (literal) |
    ///
    /// ## Logical Operators
    ///
    /// | Term | Description | IMAP Key |
    /// | --- | --- | --- |
    /// | ``not(_:)`` | Negates a term | `NOT` |
    /// | ``or(_:_:)`` | Matches either term | `OR` |
    /// | ``and(_:)`` | Matches all terms | (implicit) |
    public indirect enum Term: Sendable, Equatable {
        /// Match all messages in the folder.
        ///
        /// This is equivalent to the `ALL` search key in RFC 3501.
        case all

        /// Match messages with the `\Answered` flag set.
        ///
        /// This is equivalent to the `ANSWERED` search key in RFC 3501.
        case answered

        /// Match messages with the `\Deleted` flag set.
        ///
        /// This is equivalent to the `DELETED` search key in RFC 3501.
        case deleted

        /// Match messages with the `\Flagged` flag set.
        ///
        /// This is equivalent to the `FLAGGED` search key in RFC 3501.
        case flagged

        /// Match messages with the `\Seen` flag set.
        ///
        /// This is equivalent to the `SEEN` search key in RFC 3501.
        case seen

        /// Match messages with the `\Draft` flag set.
        ///
        /// This is equivalent to the `DRAFT` search key in RFC 3501.
        case draft

        /// Match messages with the `\Recent` flag set.
        ///
        /// This is equivalent to the `RECENT` search key in RFC 3501.
        case recent

        /// Match messages with the `\Recent` flag set but not `\Seen`.
        ///
        /// This is equivalent to the `NEW` search key in RFC 3501.
        case new

        /// Match messages without the `\Recent` flag.
        ///
        /// This is equivalent to the `OLD` search key in RFC 3501.
        case old

        /// Match messages without the `\Seen` flag.
        ///
        /// This is equivalent to the `UNSEEN` search key in RFC 3501.
        case unseen

        /// Match messages without the `\Answered` flag.
        ///
        /// This is equivalent to the `UNANSWERED` search key in RFC 3501.
        case unanswered

        /// Match messages without the `\Draft` flag.
        ///
        /// This is equivalent to the `UNDRAFT` search key in RFC 3501.
        case undraft

        /// Match messages where the From header contains the specified text.
        ///
        /// - Parameter text: The text to search for in the From header.
        ///
        /// This is equivalent to the `FROM` search key in RFC 3501.
        case from(String)

        /// Match messages where the To header contains the specified text.
        ///
        /// - Parameter text: The text to search for in the To header.
        ///
        /// This is equivalent to the `TO` search key in RFC 3501.
        case to(String)

        /// Match messages where the Cc header contains the specified text.
        ///
        /// - Parameter text: The text to search for in the Cc header.
        ///
        /// This is equivalent to the `CC` search key in RFC 3501.
        case cc(String)

        /// Match messages where the Bcc header contains the specified text.
        ///
        /// - Parameter text: The text to search for in the Bcc header.
        ///
        /// This is equivalent to the `BCC` search key in RFC 3501.
        case bcc(String)

        /// Match messages where the Subject header contains the specified text.
        ///
        /// - Parameter text: The text to search for in the Subject header.
        ///
        /// This is equivalent to the `SUBJECT` search key in RFC 3501.
        case subject(String)

        /// Match messages where the message body contains the specified text.
        ///
        /// - Parameter text: The text to search for in the message body.
        ///
        /// This is equivalent to the `BODY` search key in RFC 3501.
        case body(String)

        /// Match messages where the header or body contains the specified text.
        ///
        /// - Parameter text: The text to search for in the entire message.
        ///
        /// This is equivalent to the `TEXT` search key in RFC 3501.
        case text(String)

        /// Match messages where the specified header contains the specified text.
        ///
        /// - Parameters:
        ///   - name: The header field name.
        ///   - value: The text to search for in the header.
        ///
        /// This is equivalent to the `HEADER` search key in RFC 3501.
        case header(String, String)

        /// Match messages that have the specified keyword set.
        ///
        /// - Parameter keyword: The keyword (user-defined flag) to match.
        ///
        /// This is equivalent to the `KEYWORD` search key in RFC 3501.
        case keyword(String)

        /// Match messages that do not have the specified keyword set.
        ///
        /// - Parameter keyword: The keyword (user-defined flag) that should not be set.
        ///
        /// This is equivalent to the `UNKEYWORD` search key in RFC 3501.
        case unkeyword(String)

        /// Match messages delivered on the specified date.
        ///
        /// - Parameter date: The delivery date to match (time component is ignored).
        ///
        /// This is equivalent to the `ON` search key in RFC 3501.
        case on(Date)

        /// Match messages delivered after the specified date.
        ///
        /// - Parameter date: Messages delivered on or after this date match.
        ///
        /// This is equivalent to the `SINCE` search key in RFC 3501.
        case since(Date)

        /// Match messages delivered before the specified date.
        ///
        /// - Parameter date: Messages delivered before this date match.
        ///
        /// This is equivalent to the `BEFORE` search key in RFC 3501.
        case before(Date)

        /// Match messages with a Date header on the specified date.
        ///
        /// - Parameter date: The sent date to match (time component is ignored).
        ///
        /// This is equivalent to the `SENTON` search key in RFC 3501.
        case sentOn(Date)

        /// Match messages with a Date header after the specified date.
        ///
        /// - Parameter date: Messages sent on or after this date match.
        ///
        /// This is equivalent to the `SENTSINCE` search key in RFC 3501.
        case sentSince(Date)

        /// Match messages with a Date header before the specified date.
        ///
        /// - Parameter date: Messages sent before this date match.
        ///
        /// This is equivalent to the `SENTBEFORE` search key in RFC 3501.
        case sentBefore(Date)

        /// Match messages larger than the specified size in octets.
        ///
        /// - Parameter octets: The minimum message size.
        ///
        /// This is equivalent to the `LARGER` search key in RFC 3501.
        case larger(Int)

        /// Match messages smaller than the specified size in octets.
        ///
        /// - Parameter octets: The maximum message size.
        ///
        /// This is equivalent to the `SMALLER` search key in RFC 3501.
        case smaller(Int)

        /// Match messages with the specified unique identifiers.
        ///
        /// - Parameter set: A UID set string (e.g., "1:100" or "1,5,10").
        ///
        /// This is equivalent to the `UID` search key in RFC 3501.
        case uid(String)

        /// Negate the enclosed term (logical NOT).
        ///
        /// - Parameter term: The term to negate.
        ///
        /// This is equivalent to the `NOT` search key in RFC 3501.
        case not(Term)

        /// Match messages matching either term (logical OR).
        ///
        /// - Parameters:
        ///   - lhs: The first term.
        ///   - rhs: The second term.
        ///
        /// This is equivalent to the `OR` search key in RFC 3501.
        case or(Term, Term)

        /// Match messages matching all terms (logical AND).
        ///
        /// - Parameter terms: The terms that must all match.
        ///
        /// In IMAP, multiple search keys are implicitly ANDed together.
        case and([Term])

        /// Include raw IMAP search text directly in the query.
        ///
        /// - Parameter value: Raw IMAP SEARCH syntax to include.
        ///
        /// Use this for server-specific extensions or unsupported search keys.
        case raw(String)
    }

    /// The search term that defines this query.
    public let term: Term

    /// Creates a search query with the specified term.
    ///
    /// - Parameter term: The search term to use.
    ///
    /// Typically you'll use the static factory methods instead of this initializer:
    ///
    /// ```swift
    /// // Preferred: use static methods
    /// let query = SearchQuery.from("alice@example.com")
    ///
    /// // Also valid: use initializer with Term
    /// let query = SearchQuery(.from("alice@example.com"))
    /// ```
    public init(_ term: Term) {
        self.term = term
    }

    /// A textual representation of the query in IMAP SEARCH syntax.
    ///
    /// This is equivalent to calling ``serialize()``.
    public var description: String {
        serialize()
    }

    /// Serializes the query to IMAP SEARCH command syntax.
    ///
    /// - Returns: A string suitable for use in an IMAP SEARCH command.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let query = SearchQuery.from("alice@example.com").and(.unseen)
    /// print(query.serialize())
    /// // Output: FROM "alice@example.com" UNSEEN
    /// ```
    public func serialize() -> String {
        Self.serialize(term)
    }

    /// Returns an optimized version of this query.
    ///
    /// Query optimization simplifies the query by:
    /// - Eliminating double negations
    /// - Flattening nested AND operations
    /// - Removing redundant ALL terms
    /// - Eliminating duplicate terms
    ///
    /// - Parameter optimizer: The optimizer to use. Defaults to ``DefaultSearchQueryOptimizer``.
    /// - Returns: An optimized search query.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Before optimization: NOT (NOT (FROM "alice"))
    /// let query = SearchQuery.not(.not(.from("alice@example.com")))
    ///
    /// // After optimization: FROM "alice"
    /// let optimized = query.optimized()
    /// ```
    ///
    /// ## See Also
    /// - ``SearchQueryOptimizer``
    /// - ``DefaultSearchQueryOptimizer``
    public func optimized(using optimizer: SearchQueryOptimizer = DefaultSearchQueryOptimizer()) -> SearchQuery {
        optimizer.optimize(self)
    }

    /// Creates a new query that matches messages matching both this query and another.
    ///
    /// - Parameter other: The query to AND with this query.
    /// - Returns: A new query matching messages that satisfy both conditions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Find unread messages from Alice
    /// let query = SearchQuery.from("alice@example.com").and(.unseen)
    /// ```
    ///
    /// ## See Also
    /// - ``and(_:)-4j9i3``
    public func and(_ other: SearchQuery) -> SearchQuery {
        SearchQuery(.and([term, other.term]))
    }

    /// Creates a new query that matches messages matching either this query or another.
    ///
    /// - Parameter other: The query to OR with this query.
    /// - Returns: A new query matching messages that satisfy either condition.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Find messages that are either flagged or unread
    /// let query = SearchQuery.flagged.or(.unseen)
    /// ```
    ///
    /// ## See Also
    /// - ``or(_:_:)``
    public func or(_ other: SearchQuery) -> SearchQuery {
        SearchQuery(.or(term, other.term))
    }

    /// Creates a new query that matches messages NOT matching this query.
    ///
    /// - Returns: A negated version of this query.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Find messages NOT from Alice
    /// let query = SearchQuery.from("alice@example.com").not()
    /// ```
    ///
    /// ## See Also
    /// - ``not(_:)``
    public func not() -> SearchQuery {
        SearchQuery(.not(term))
    }
}

// MARK: - Static Factory Methods

public extension SearchQuery {
    // MARK: Flag Queries

    /// Match all messages in the folder.
    ///
    /// This is equivalent to the `ALL` search key in RFC 3501.
    ///
    /// ```swift
    /// let allMessages = SearchQuery.all
    /// ```
    static var all: SearchQuery { SearchQuery(.all) }

    /// Match messages with the `\Answered` flag set.
    ///
    /// This is equivalent to the `ANSWERED` search key in RFC 3501.
    ///
    /// ```swift
    /// let replied = SearchQuery.answered
    /// ```
    static var answered: SearchQuery { SearchQuery(.answered) }

    /// Match messages with the `\Deleted` flag set.
    ///
    /// This is equivalent to the `DELETED` search key in RFC 3501.
    ///
    /// ```swift
    /// let deleted = SearchQuery.deleted
    /// ```
    static var deleted: SearchQuery { SearchQuery(.deleted) }

    /// Match messages with the `\Flagged` flag set.
    ///
    /// This is equivalent to the `FLAGGED` search key in RFC 3501.
    ///
    /// ```swift
    /// let starred = SearchQuery.flagged
    /// ```
    static var flagged: SearchQuery { SearchQuery(.flagged) }

    /// Match messages with the `\Seen` flag set.
    ///
    /// This is equivalent to the `SEEN` search key in RFC 3501.
    ///
    /// ```swift
    /// let read = SearchQuery.seen
    /// ```
    static var seen: SearchQuery { SearchQuery(.seen) }

    /// Match messages with the `\Draft` flag set.
    ///
    /// This is equivalent to the `DRAFT` search key in RFC 3501.
    ///
    /// ```swift
    /// let drafts = SearchQuery.draft
    /// ```
    static var draft: SearchQuery { SearchQuery(.draft) }

    /// Match messages with the `\Recent` flag set.
    ///
    /// This is equivalent to the `RECENT` search key in RFC 3501.
    ///
    /// ```swift
    /// let recentMessages = SearchQuery.recent
    /// ```
    static var recent: SearchQuery { SearchQuery(.recent) }

    /// Match messages with the `\Recent` flag set but not `\Seen`.
    ///
    /// This is equivalent to the `NEW` search key in RFC 3501.
    ///
    /// ```swift
    /// let newMessages = SearchQuery.new
    /// ```
    static var new: SearchQuery { SearchQuery(.new) }

    /// Match messages without the `\Recent` flag.
    ///
    /// This is equivalent to the `OLD` search key in RFC 3501.
    ///
    /// ```swift
    /// let oldMessages = SearchQuery.old
    /// ```
    static var old: SearchQuery { SearchQuery(.old) }

    /// Match messages without the `\Seen` flag.
    ///
    /// This is equivalent to the `UNSEEN` search key in RFC 3501.
    ///
    /// ```swift
    /// let unread = SearchQuery.unseen
    /// ```
    static var unseen: SearchQuery { SearchQuery(.unseen) }

    /// Match messages without the `\Answered` flag.
    ///
    /// This is equivalent to the `UNANSWERED` search key in RFC 3501.
    ///
    /// ```swift
    /// let noReply = SearchQuery.unanswered
    /// ```
    static var unanswered: SearchQuery { SearchQuery(.unanswered) }

    /// Match messages without the `\Draft` flag.
    ///
    /// This is equivalent to the `UNDRAFT` search key in RFC 3501.
    ///
    /// ```swift
    /// let notDrafts = SearchQuery.undraft
    /// ```
    static var undraft: SearchQuery { SearchQuery(.undraft) }

    // MARK: Header Queries

    /// Match messages where the From header contains the specified text.
    ///
    /// - Parameter text: The text to search for in the From header.
    /// - Returns: A search query matching the From header.
    ///
    /// This is equivalent to the `FROM` search key in RFC 3501.
    ///
    /// ```swift
    /// let fromAlice = SearchQuery.from("alice@example.com")
    /// ```
    static func from(_ text: String) -> SearchQuery { SearchQuery(.from(text)) }

    /// Match messages where the To header contains the specified text.
    ///
    /// - Parameter text: The text to search for in the To header.
    /// - Returns: A search query matching the To header.
    ///
    /// This is equivalent to the `TO` search key in RFC 3501.
    ///
    /// ```swift
    /// let toSupport = SearchQuery.to("support@example.com")
    /// ```
    static func to(_ text: String) -> SearchQuery { SearchQuery(.to(text)) }

    /// Match messages where the Cc header contains the specified text.
    ///
    /// - Parameter text: The text to search for in the Cc header.
    /// - Returns: A search query matching the Cc header.
    ///
    /// This is equivalent to the `CC` search key in RFC 3501.
    ///
    /// ```swift
    /// let ccManager = SearchQuery.cc("manager@example.com")
    /// ```
    static func cc(_ text: String) -> SearchQuery { SearchQuery(.cc(text)) }

    /// Match messages where the Bcc header contains the specified text.
    ///
    /// - Parameter text: The text to search for in the Bcc header.
    /// - Returns: A search query matching the Bcc header.
    ///
    /// This is equivalent to the `BCC` search key in RFC 3501.
    ///
    /// ```swift
    /// let bccAdmin = SearchQuery.bcc("admin@example.com")
    /// ```
    static func bcc(_ text: String) -> SearchQuery { SearchQuery(.bcc(text)) }

    /// Match messages where the Subject header contains the specified text.
    ///
    /// - Parameter text: The text to search for in the Subject header.
    /// - Returns: A search query matching the Subject header.
    ///
    /// This is equivalent to the `SUBJECT` search key in RFC 3501.
    ///
    /// ```swift
    /// let urgent = SearchQuery.subject("URGENT")
    /// ```
    static func subject(_ text: String) -> SearchQuery { SearchQuery(.subject(text)) }

    /// Match messages where the message body contains the specified text.
    ///
    /// - Parameter text: The text to search for in the message body.
    /// - Returns: A search query matching the body content.
    ///
    /// This is equivalent to the `BODY` search key in RFC 3501.
    ///
    /// ```swift
    /// let mentionsProject = SearchQuery.body("Project X")
    /// ```
    static func body(_ text: String) -> SearchQuery { SearchQuery(.body(text)) }

    /// Match messages where the header or body contains the specified text.
    ///
    /// - Parameter text: The text to search for anywhere in the message.
    /// - Returns: A search query matching any part of the message.
    ///
    /// This is equivalent to the `TEXT` search key in RFC 3501.
    ///
    /// ```swift
    /// let mentionsAnywhere = SearchQuery.text("important")
    /// ```
    static func text(_ text: String) -> SearchQuery { SearchQuery(.text(text)) }

    /// Match messages where the specified header contains the specified text.
    ///
    /// - Parameters:
    ///   - name: The header field name (e.g., "X-Priority", "Message-ID").
    ///   - value: The text to search for in the header.
    /// - Returns: A search query matching the specified header.
    ///
    /// This is equivalent to the `HEADER` search key in RFC 3501.
    ///
    /// ```swift
    /// let highPriority = SearchQuery.header("X-Priority", "1")
    /// let fromMailingList = SearchQuery.header("List-Id", "dev-list")
    /// ```
    static func header(_ name: String, _ value: String) -> SearchQuery { SearchQuery(.header(name, value)) }

    /// Match messages that have the specified keyword (user-defined flag) set.
    ///
    /// - Parameter keyword: The keyword to match.
    /// - Returns: A search query matching messages with the keyword.
    ///
    /// This is equivalent to the `KEYWORD` search key in RFC 3501.
    ///
    /// ```swift
    /// let importantMessages = SearchQuery.keyword("$Important")
    /// ```
    static func keyword(_ keyword: String) -> SearchQuery { SearchQuery(.keyword(keyword)) }

    /// Match messages that do not have the specified keyword set.
    ///
    /// - Parameter keyword: The keyword that should not be set.
    /// - Returns: A search query matching messages without the keyword.
    ///
    /// This is equivalent to the `UNKEYWORD` search key in RFC 3501.
    ///
    /// ```swift
    /// let notForwarded = SearchQuery.unkeyword("$Forwarded")
    /// ```
    static func unkeyword(_ keyword: String) -> SearchQuery { SearchQuery(.unkeyword(keyword)) }

    // MARK: Date Queries

    /// Match messages delivered on the specified date.
    ///
    /// - Parameter date: The delivery date to match. The time component is ignored.
    /// - Returns: A search query matching messages delivered on that date.
    ///
    /// This is equivalent to the `ON` search key in RFC 3501.
    ///
    /// ```swift
    /// let onChristmas = SearchQuery.on(christmasDate)
    /// ```
    static func on(_ date: Date) -> SearchQuery { SearchQuery(.on(date)) }

    /// Match messages delivered on or after the specified date.
    ///
    /// - Parameter date: The earliest delivery date to match.
    /// - Returns: A search query matching messages delivered since that date.
    ///
    /// This is equivalent to the `SINCE` search key in RFC 3501.
    ///
    /// ```swift
    /// let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    /// let recentMessages = SearchQuery.since(lastWeek)
    /// ```
    static func since(_ date: Date) -> SearchQuery { SearchQuery(.since(date)) }

    /// Match messages delivered before the specified date.
    ///
    /// - Parameter date: The latest delivery date (exclusive) to match.
    /// - Returns: A search query matching messages delivered before that date.
    ///
    /// This is equivalent to the `BEFORE` search key in RFC 3501.
    ///
    /// ```swift
    /// let beforeNewYear = SearchQuery.before(newYearDate)
    /// ```
    static func before(_ date: Date) -> SearchQuery { SearchQuery(.before(date)) }

    /// Match messages with a Date header on the specified date.
    ///
    /// - Parameter date: The sent date to match. The time component is ignored.
    /// - Returns: A search query matching messages sent on that date.
    ///
    /// This is equivalent to the `SENTON` search key in RFC 3501.
    ///
    /// ```swift
    /// let sentOnBirthday = SearchQuery.sentOn(birthdayDate)
    /// ```
    static func sentOn(_ date: Date) -> SearchQuery { SearchQuery(.sentOn(date)) }

    /// Match messages with a Date header on or after the specified date.
    ///
    /// - Parameter date: The earliest sent date to match.
    /// - Returns: A search query matching messages sent since that date.
    ///
    /// This is equivalent to the `SENTSINCE` search key in RFC 3501.
    ///
    /// ```swift
    /// let sentRecently = SearchQuery.sentSince(lastWeek)
    /// ```
    static func sentSince(_ date: Date) -> SearchQuery { SearchQuery(.sentSince(date)) }

    /// Match messages with a Date header before the specified date.
    ///
    /// - Parameter date: The latest sent date (exclusive) to match.
    /// - Returns: A search query matching messages sent before that date.
    ///
    /// This is equivalent to the `SENTBEFORE` search key in RFC 3501.
    ///
    /// ```swift
    /// let sentBeforeDeadline = SearchQuery.sentBefore(deadlineDate)
    /// ```
    static func sentBefore(_ date: Date) -> SearchQuery { SearchQuery(.sentBefore(date)) }

    // MARK: Size Queries

    /// Match messages larger than the specified size in octets.
    ///
    /// - Parameter octets: The minimum message size in bytes.
    /// - Returns: A search query matching large messages.
    ///
    /// This is equivalent to the `LARGER` search key in RFC 3501.
    ///
    /// ```swift
    /// // Find messages larger than 1 MB
    /// let largeMessages = SearchQuery.larger(1_000_000)
    /// ```
    static func larger(_ octets: Int) -> SearchQuery { SearchQuery(.larger(octets)) }

    /// Match messages smaller than the specified size in octets.
    ///
    /// - Parameter octets: The maximum message size in bytes.
    /// - Returns: A search query matching small messages.
    ///
    /// This is equivalent to the `SMALLER` search key in RFC 3501.
    ///
    /// ```swift
    /// // Find messages smaller than 10 KB
    /// let smallMessages = SearchQuery.smaller(10_000)
    /// ```
    static func smaller(_ octets: Int) -> SearchQuery { SearchQuery(.smaller(octets)) }

    // MARK: UID Queries

    /// Match messages with the specified unique identifiers.
    ///
    /// - Parameter set: A UID set string in IMAP format (e.g., "1:100", "1,5,10", "1:*").
    /// - Returns: A search query matching the specified UIDs.
    ///
    /// This is equivalent to the `UID` search key in RFC 3501.
    ///
    /// ```swift
    /// let specificMessages = SearchQuery.uid("1,5,10:20")
    /// ```
    static func uid(_ set: String) -> SearchQuery { SearchQuery(.uid(set)) }

    /// Match messages with the specified unique identifiers.
    ///
    /// - Parameter set: A ``UniqueIdSet`` containing the UIDs to match.
    /// - Returns: A search query matching the specified UIDs.
    ///
    /// This is equivalent to the `UID` search key in RFC 3501.
    ///
    /// ```swift
    /// let uidSet = UniqueIdSet(ranges: [1...10, 20...30])
    /// let messages = SearchQuery.uid(uidSet)
    /// ```
    static func uid(_ set: UniqueIdSet) -> SearchQuery { SearchQuery(.uid(set.description)) }

    /// Match messages with the specified unique identifiers.
    ///
    /// - Parameter ids: An array of ``UniqueId`` values to match.
    /// - Returns: A search query matching the specified UIDs.
    ///
    /// This is equivalent to the `UID` search key in RFC 3501.
    ///
    /// ```swift
    /// let messages = SearchQuery.uid([uid1, uid2, uid3])
    /// ```
    static func uid(_ ids: [UniqueId]) -> SearchQuery { SearchQuery(.uid(UniqueIdSet(ids).description)) }

    // MARK: Logical Operators

    /// Create a logical negation of the specified query.
    ///
    /// - Parameter query: The query to negate.
    /// - Returns: A query matching messages that do NOT match the input query.
    ///
    /// This is equivalent to the `NOT` search key in RFC 3501.
    ///
    /// ```swift
    /// // Find messages NOT from Alice
    /// let notFromAlice = SearchQuery.not(.from("alice@example.com"))
    /// ```
    static func not(_ query: SearchQuery) -> SearchQuery { SearchQuery(.not(query.term)) }

    /// Create a conditional OR operation between two queries.
    ///
    /// - Parameters:
    ///   - lhs: The first query operand.
    ///   - rhs: The second query operand.
    /// - Returns: A query matching messages that match either operand.
    ///
    /// This is equivalent to the `OR` search key in RFC 3501.
    ///
    /// ```swift
    /// // Find messages that are either flagged or unread
    /// let important = SearchQuery.or(.flagged, .unseen)
    /// ```
    static func or(_ lhs: SearchQuery, _ rhs: SearchQuery) -> SearchQuery { SearchQuery(.or(lhs.term, rhs.term)) }

    /// Create a conditional AND operation combining multiple queries.
    ///
    /// - Parameter queries: The queries that must all match.
    /// - Returns: A query matching messages that satisfy all input queries.
    ///
    /// In IMAP, multiple search keys are implicitly ANDed together.
    ///
    /// ```swift
    /// // Find unread messages from Alice about Project X
    /// let query = SearchQuery.and([
    ///     .from("alice@example.com"),
    ///     .subject("Project X"),
    ///     .unseen
    /// ])
    /// ```
    static func and(_ queries: [SearchQuery]) -> SearchQuery { SearchQuery(.and(queries.map { $0.term })) }

    /// Include raw IMAP search text directly in the query.
    ///
    /// - Parameter value: Raw IMAP SEARCH syntax to include.
    /// - Returns: A query containing the raw search text.
    ///
    /// Use this for server-specific extensions or search keys not directly supported
    /// by the `SearchQuery` API.
    ///
    /// ```swift
    /// // Use a server-specific extension
    /// let gmailSearch = SearchQuery.raw("X-GM-RAW \"has:attachment\"")
    /// ```
    ///
    /// - Warning: No validation is performed on the raw text. Ensure the syntax
    ///   is correct for your target IMAP server.
    static func raw(_ value: String) -> SearchQuery { SearchQuery(.raw(value)) }
}

// MARK: - Serialization (Private)

private extension SearchQuery {
    /// Serializes a search term to IMAP SEARCH command syntax.
    ///
    /// - Parameter term: The term to serialize.
    /// - Returns: A string in IMAP SEARCH format.
    static func serialize(_ term: Term) -> String {
        switch term {
        case .all:
            return "ALL"
        case .answered:
            return "ANSWERED"
        case .deleted:
            return "DELETED"
        case .flagged:
            return "FLAGGED"
        case .seen:
            return "SEEN"
        case .draft:
            return "DRAFT"
        case .recent:
            return "RECENT"
        case .new:
            return "NEW"
        case .old:
            return "OLD"
        case .unseen:
            return "UNSEEN"
        case .unanswered:
            return "UNANSWERED"
        case .undraft:
            return "UNDRAFT"
        case let .from(value):
            return "FROM \(quote(value))"
        case let .to(value):
            return "TO \(quote(value))"
        case let .cc(value):
            return "CC \(quote(value))"
        case let .bcc(value):
            return "BCC \(quote(value))"
        case let .subject(value):
            return "SUBJECT \(quote(value))"
        case let .body(value):
            return "BODY \(quote(value))"
        case let .text(value):
            return "TEXT \(quote(value))"
        case let .header(name, value):
            return "HEADER \(quote(name)) \(quote(value))"
        case let .keyword(value):
            return "KEYWORD \(quote(value))"
        case let .unkeyword(value):
            return "UNKEYWORD \(quote(value))"
        case let .on(date):
            return "ON \(formatDate(date))"
        case let .since(date):
            return "SINCE \(formatDate(date))"
        case let .before(date):
            return "BEFORE \(formatDate(date))"
        case let .sentOn(date):
            return "SENTON \(formatDate(date))"
        case let .sentSince(date):
            return "SENTSINCE \(formatDate(date))"
        case let .sentBefore(date):
            return "SENTBEFORE \(formatDate(date))"
        case let .larger(size):
            return "LARGER \(size)"
        case let .smaller(size):
            return "SMALLER \(size)"
        case let .uid(value):
            return "UID \(value)"
        case let .not(inner):
            let rendered = serialize(inner)
            if needsGrouping(inner) {
                return "NOT (\(rendered))"
            }
            return "NOT \(rendered)"
        case let .or(lhs, rhs):
            let left = serialize(lhs)
            let right = serialize(rhs)
            let leftRendered = needsGrouping(lhs) ? "(\(left))" : left
            let rightRendered = needsGrouping(rhs) ? "(\(right))" : right
            return "OR \(leftRendered) \(rightRendered)"
        case let .and(terms):
            if terms.isEmpty {
                return "ALL"
            }
            return terms.map { serialize($0) }.joined(separator: " ")
        case let .raw(value):
            return value
        }
    }

    /// Quotes a string value for use in IMAP SEARCH commands.
    ///
    /// Escapes backslashes and double quotes within the string.
    ///
    /// - Parameter value: The string to quote.
    /// - Returns: A quoted string suitable for IMAP.
    static func quote(_ value: String) -> String {
        var result = "\""
        for ch in value {
            if ch == "\\" || ch == "\"" {
                result.append("\\")
            }
            result.append(ch)
        }
        result.append("\"")
        return result
    }

    /// Formats a date for IMAP SEARCH commands.
    ///
    /// IMAP dates use the format "dd-MMM-yyyy" (e.g., "01-Jan-2024").
    ///
    /// - Parameter date: The date to format.
    /// - Returns: A string in IMAP date format.
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "dd-MMM-yyyy"
        return formatter.string(from: date)
    }

    /// Determines whether a term needs parentheses when used as an operand.
    ///
    /// Compound terms (multi-element AND, OR) need grouping to preserve semantics.
    ///
    /// - Parameter term: The term to check.
    /// - Returns: `true` if the term needs parentheses when nested.
    static func needsGrouping(_ term: Term) -> Bool {
        switch term {
        case .and(let terms):
            return terms.count > 1
        case .or:
            return true
        default:
            return false
        }
    }
}
