import Testing
@testable import MailFoundation

@Test("SearchQuery optimizer flattens AND and removes ALL")
func searchQueryOptimizerFlattensAndRemovesAll() {
    let query = SearchQuery(.and([.all, .from("alice@example.com"), .and([.unseen, .all])]))
    let optimized = query.optimized()
    #expect(optimized.serialize() == "FROM \"alice@example.com\" UNSEEN")
}

@Test("SearchQuery optimizer removes duplicate terms")
func searchQueryOptimizerRemovesDuplicates() {
    let query = SearchQuery(.and([.seen, .seen, .flagged]))
    let optimized = query.optimized()
    #expect(optimized.serialize() == "SEEN FLAGGED")
}

@Test("SearchQuery optimizer simplifies double NOT")
func searchQueryOptimizerSimplifiesDoubleNot() {
    let query = SearchQuery(.not(.not(.seen)))
    let optimized = query.optimized()
    #expect(optimized.serialize() == "SEEN")
}

@Test("SearchQuery optimizer collapses OR with ALL")
func searchQueryOptimizerOrWithAll() {
    let query = SearchQuery(.or(.all, .from("alice@example.com")))
    let optimized = query.optimized()
    #expect(optimized.serialize() == "ALL")
}

@Test("SearchQuery optimizer collapses OR duplicates")
func searchQueryOptimizerOrDuplicates() {
    let query = SearchQuery(.or(.seen, .seen))
    let optimized = query.optimized()
    #expect(optimized.serialize() == "SEEN")
}

