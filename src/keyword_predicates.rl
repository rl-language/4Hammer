import state_types

# Appendix02.05.01 (https://wahapedia.ru/wh40k11ed/the-rules/rules-appendix/):
# adjacent keywords require ALL, slash/comma/or lists require ANY, and non-X
# excludes X. A predicate combines these three clauses, rather than flattening
# every condition into one positive OR list.
enum KeywordClause:
    all
    any
    none

    # Metadata comparison, not an additional tabletop rule.
    fun equal(KeywordClause other) -> Bool:
        return self.value == other.value

# Retain the previous first-keyword plus eight alternatives capacity. Fixed
# arrays avoid owning allocations in empty weapon-rule vectors; all stored
# values remain bounded/enum data for the inferred observation layout.
const MAX_KEYWORD_TERMS = 9
const KEYWORD_TERM_BOUND = 10
cls KeywordPredicate:
    # Three ordinary bounded counts describe contiguous ALL/ANY/NONE groups.
    # Do not repeat a categorical tag per term in every weapon snapshot: that
    # needlessly doubles the inferred game observation. No custom tensor codec.
    LinearlyDistributedInt<0, KEYWORD_TERM_BOUND> required_count
    LinearlyDistributedInt<0, KEYWORD_TERM_BOUND> alternative_count
    LinearlyDistributedInt<0, KEYWORD_TERM_BOUND> excluded_count
    LinearlyDistributedInt<0, 128>[MAX_KEYWORD_TERMS] keywords

    # The total is computed, never stored redundantly (appendix02.05.01).
    fun size() -> Int:
        return self.required_count.value + self.alternative_count.value + self.excluded_count.value

    # Reconstruct the semantic enum for a term's group, not a packed numeric
    # representation; this is metadata for appendix02.05.01/editor labels.
    fun clause(Int entry) -> KeywordClause:
        assert(entry >= 0 and entry < self.size() and self.size() <= MAX_KEYWORD_TERMS, "invalid keyword condition entry")
        if entry < self.required_count.value:
            return KeywordClause::all
        if entry < self.required_count.value + self.alternative_count.value:
            return KeywordClause::any
        return KeywordClause::none

    # Validate group bounds before lookup; unknown keyword IDs cannot create
    # permissions or negative-condition matches (appendix02.05.01).
    fun valid(Int last_keyword) -> Bool:
        if self.required_count.value < 0 or self.required_count.value > MAX_KEYWORD_TERMS or self.alternative_count.value < 0 or self.alternative_count.value > MAX_KEYWORD_TERMS or self.excluded_count.value < 0 or self.excluded_count.value > MAX_KEYWORD_TERMS:
            return false
        if self.size() > MAX_KEYWORD_TERMS:
            return false
        for term in range(self.size()):
            if self.keywords[term].value < 0 or self.keywords[term].value > last_keyword:
                return false
        return true

    # Data construction is atomic; identical terms do not consume capacity,
    # while contradictory ALL/NONE terms retain their literal false meaning.
    # Insert into the relevant group without owning allocations or lifecycle hooks.
    fun append(KeywordClause added_clause, Int keyword, Int last_keyword) -> Bool:
        if !self.valid(last_keyword) or added_clause.value < 0 or added_clause.value > KeywordClause::none.value or keyword < 0 or keyword > last_keyword or keyword >= 128:
            return false
        for term in range(self.size()):
            if self.clause(term) == added_clause and self.keywords[term].value == keyword:
                return true
        if self.size() == MAX_KEYWORD_TERMS:
            return false
        let insertion = self.size()
        if added_clause == KeywordClause::all:
            insertion = self.required_count.value
        if added_clause == KeywordClause::any:
            insertion = self.required_count.value + self.alternative_count.value
        let shifted = self.size()
        while shifted > insertion:
            self.keywords[shifted] = self.keywords[shifted - 1]
            shifted = shifted - 1
        self.keywords[insertion] = keyword
        if added_clause == KeywordClause::all:
            self.required_count = self.required_count + 1
        if added_clause == KeywordClause::any:
            self.alternative_count = self.alternative_count + 1
        if added_clause == KeywordClause::none:
            self.excluded_count = self.excluded_count + 1
        return true
