//
// Author: Jeffrey Stedfast <jestedfa@microsoft.com>
//
// Copyright (c) 2013-2026 .NET Foundation and Contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

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

