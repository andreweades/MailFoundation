//
// SearchQueryOptimizer.swift
//
// Search query optimization helpers.
//

public protocol SearchQueryOptimizer: Sendable {
    func optimize(_ query: SearchQuery) -> SearchQuery
}

public struct DefaultSearchQueryOptimizer: SearchQueryOptimizer, Sendable {
    public init() {}

    public func optimize(_ query: SearchQuery) -> SearchQuery {
        SearchQuery(Self.optimize(term: query.term))
    }

    private static func optimize(term: SearchQuery.Term) -> SearchQuery.Term {
        switch term {
        case .not(let inner):
            let optimized = optimize(term: inner)
            if case .not(let nested) = optimized {
                return nested
            }
            return .not(optimized)
        case .and(let terms):
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
            if left == .all || right == .all {
                return .all
            }
            if left == right {
                return left
            }
            return .or(left, right)
        default:
            return term
        }
    }

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

