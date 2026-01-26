//
// SearchQueryOptimizer.swift
//
// Search query optimization helpers.
//

/// A protocol for optimizing search queries before they are serialized and sent to a server.
///
/// Search query optimizers can simplify, canonicalize, or transform search queries
/// to improve performance or reduce redundancy. Implementations of this protocol
/// receive a ``SearchQuery`` and return an optimized version of it.
///
/// ## Overview
///
/// Optimization typically involves:
/// - Eliminating double negations (`NOT NOT x` becomes `x`)
/// - Flattening nested AND operations
/// - Removing redundant `ALL` terms from conjunctions
/// - Eliminating duplicate terms
/// - Short-circuiting OR operations that include `ALL`
///
/// ## Implementing a Custom Optimizer
///
/// You can create a custom optimizer by conforming to this protocol:
///
/// ```swift
/// struct MyOptimizer: SearchQueryOptimizer {
///     func optimize(_ query: SearchQuery) -> SearchQuery {
///         // Custom optimization logic
///         return query
///     }
/// }
/// ```
///
/// ## See Also
/// - ``DefaultSearchQueryOptimizer``
/// - ``SearchQuery/optimized(using:)``
public protocol SearchQueryOptimizer: Sendable {
    /// Optimizes the given search query.
    ///
    /// - Parameter query: The search query to optimize.
    /// - Returns: An optimized version of the query.
    func optimize(_ query: SearchQuery) -> SearchQuery
}

/// The default search query optimizer that performs common simplifications.
///
/// `DefaultSearchQueryOptimizer` applies the following optimizations to search queries:
///
/// - **Double negation elimination**: `NOT (NOT x)` is reduced to `x`
/// - **AND flattening**: Nested AND operations are flattened into a single AND
/// - **ALL removal**: `ALL` terms are removed from AND conjunctions (since `x AND ALL` equals `x`)
/// - **Deduplication**: Duplicate terms within AND operations are removed
/// - **OR short-circuit**: `x OR ALL` is reduced to `ALL` (matches all messages)
/// - **OR deduplication**: `x OR x` is reduced to `x`
/// - **Single-element AND**: An AND with one element is reduced to that element
/// - **Empty AND**: An AND with no elements (after pruning) becomes `ALL`
///
/// ## Usage
///
/// ```swift
/// let optimizer = DefaultSearchQueryOptimizer()
///
/// // Double negation is eliminated
/// let query1 = SearchQuery.not(.not(.from("alice@example.com")))
/// let optimized1 = optimizer.optimize(query1)
/// // Result: .from("alice@example.com")
///
/// // Redundant ALL terms are removed
/// let query2 = SearchQuery.and([.all, .from("bob@example.com"), .all])
/// let optimized2 = optimizer.optimize(query2)
/// // Result: .from("bob@example.com")
///
/// // OR with ALL short-circuits
/// let query3 = SearchQuery.or(.from("carol@example.com"), .all)
/// let optimized3 = optimizer.optimize(query3)
/// // Result: .all
/// ```
///
/// You can also use the convenience method on ``SearchQuery``:
///
/// ```swift
/// let optimizedQuery = myQuery.optimized()
/// // or with a custom optimizer:
/// let optimizedQuery = myQuery.optimized(using: MyCustomOptimizer())
/// ```
///
/// ## See Also
/// - ``SearchQueryOptimizer``
/// - ``SearchQuery/optimized(using:)``
public struct DefaultSearchQueryOptimizer: SearchQueryOptimizer, Sendable {
    /// Creates a new default search query optimizer.
    public init() {}

    /// Optimizes the given search query using default optimization rules.
    ///
    /// - Parameter query: The search query to optimize.
    /// - Returns: An optimized version of the query.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let optimizer = DefaultSearchQueryOptimizer()
    ///
    /// // Before: NOT (NOT (FROM "alice"))
    /// let query = SearchQuery.not(.not(.from("alice@example.com")))
    ///
    /// // After: FROM "alice"
    /// let optimized = optimizer.optimize(query)
    /// ```
    public func optimize(_ query: SearchQuery) -> SearchQuery {
        SearchQuery(Self.optimize(term: query.term))
    }

    /// Recursively optimizes a search term.
    ///
    /// - Parameter term: The term to optimize.
    /// - Returns: An optimized version of the term.
    private static func optimize(term: SearchQuery.Term) -> SearchQuery.Term {
        switch term {
        case .not(let inner):
            let optimized = optimize(term: inner)
            // Double negation elimination: NOT (NOT x) = x
            if case .not(let nested) = optimized {
                return nested
            }
            return .not(optimized)
        case .and(let terms):
            // Flatten nested ANDs and optimize each term
            var flattened: [SearchQuery.Term] = []
            flattened.reserveCapacity(terms.count)
            for term in terms {
                let optimized = optimize(term: term)
                if case .and(let nested) = optimized {
                    flattened.append(contentsOf: nested)
                } else {
                    flattened.append(optimized)
                }
            }
            // Remove ALL terms (x AND ALL = x) and deduplicate
            let pruned = dedupe(flattened.filter { $0 != .all })
            if pruned.isEmpty {
                return .all
            }
            if pruned.count == 1, let only = pruned.first {
                return only
            }
            return .and(pruned)
        case .or(let lhs, let rhs):
            let left = optimize(term: lhs)
            let right = optimize(term: rhs)
            // Short-circuit: x OR ALL = ALL
            if left == .all || right == .all {
                return .all
            }
            // Eliminate duplicate: x OR x = x
            if left == right {
                return left
            }
            return .or(left, right)
        default:
            return term
        }
    }

    /// Removes duplicate terms from an array while preserving order.
    ///
    /// - Parameter terms: The array of terms to deduplicate.
    /// - Returns: An array with duplicates removed.
    private static func dedupe(_ terms: [SearchQuery.Term]) -> [SearchQuery.Term] {
        guard terms.count > 1 else { return terms }
        var unique: [SearchQuery.Term] = []
        unique.reserveCapacity(terms.count)
        for term in terms where !unique.contains(term) {
            unique.append(term)
        }
        return unique
    }
}

