from app.services.chat_search_ranking import ChatSearchRanking


def test_chat_search_builds_generic_term_variants():
    ranking = ChatSearchRanking()

    assert "notebook" in ranking.expand_terms("Search chats for notebooks")
    assert "planning" in ranking.expand_terms("What did I say about planning?")
    assert "plan" in ranking.expand_terms("What did I say about planning?")
    assert "revise" in ranking.expand_terms("Did I mention revised notes?")
    assert "qr" in ranking.expand_terms("Search chats for QR code")


def test_chat_search_expands_day_numbers_and_ordinal_words():
    ranking = ChatSearchRanking()

    assert "18th" in ranking.expand_terms("18")
    assert "eighteenth" in ranking.expand_terms("18")
    assert "18" in ranking.expand_terms("eighteenth")
    assert "18th" in ranking.expand_terms("eighteenth")


def test_chat_search_normalizes_generic_model_number_forms():
    ranking = ChatSearchRanking()

    assert ranking.normalize_text("forty five") == "45"
    assert "45" in ranking.expand_terms("45L")
    assert ranking.term_in_text("45L", "It was an Omen PC forty five.")
    assert ranking.term_in_text("45 l", "The model is 45L.")


def test_chat_search_filters_noisy_recall_terms_without_dropping_acronyms():
    ranking = ChatSearchRanking()

    terms = ranking.search_terms("What kind of PC do I have?", max_terms=10)

    assert "pc" in terms
    assert "of" not in terms
    assert "kind" not in terms
    assert "have" not in terms


def test_chat_search_builds_subject_and_expanded_queries():
    ranking = ChatSearchRanking()

    queries = ranking.build_queries("Do you know anything about my notebook preference?")

    assert [query.mode for query in queries] == [
        "exact",
        "expanded_keywords",
        "subject",
        "keyword",
        "keyword",
        "keyword",
        "keyword",
    ]
    assert queries[1].query == "notebook notebooks preference preferences"
    assert queries[2].query == "notebook preference"
    assert [query.query for query in queries[3:7]] == [
        "notebook",
        "notebooks",
        "preference",
        "preferences",
    ]


def test_chat_search_prioritizes_subject_query_for_old_chat_dates():
    ranking = ChatSearchRanking()

    queries = ranking.build_queries("Can you search in old chats for June 18?")
    query_pairs = [(query.query, query.mode) for query in queries]

    assert ("june 18", "subject") in query_pairs
    assert query_pairs.index(("june 18", "subject")) < query_pairs.index(
        ("june", "keyword")
    )
    assert "18th" in queries[1].query.split()
    assert "eighteenth" in queries[1].query.split()


def test_chat_search_keeps_full_query_terms_when_subject_exists():
    ranking = ChatSearchRanking()

    queries = ranking.build_queries("What did I say about my QR code?")

    expanded = queries[1].query.split()
    assert "qr" in expanded
    assert "code" in expanded
    assert "codes" in expanded


def test_chat_search_expands_inflections_without_subject_phrase():
    ranking = ChatSearchRanking()

    queries = ranking.build_queries("What was I planning?")

    expanded = queries[1].query.split()
    assert "planning" in expanded
    assert "plan" in expanded


def test_chat_search_scores_user_exact_match_above_assistant_noise():
    ranking = ChatSearchRanking()

    user_score = ranking.score_text(
        "What did I say about Lara?",
        "Lara recommended the Somerville coffee place.",
        role="user",
    )
    assistant_score = ranking.score_text(
        "What did I say about Lara?",
        "I searched chats, but nothing about Lara came up.",
        role="assistant",
    )

    assert user_score.score > assistant_score.score
    assert "lara" in user_score.matched_terms


def test_chat_search_scores_factual_statement_above_search_question():
    ranking = ChatSearchRanking()

    factual_score = ranking.score_text(
        "What kind PC do I have?",
        "I own an Omen PC forty five.",
        role="user",
    )
    question_score = ranking.score_text(
        "What kind PC do I have?",
        "Do I have a PC?",
        role="user",
    )

    assert factual_score.score > question_score.score
    assert "factual statement" in factual_score.reason
    assert "search-question demotion" in question_score.reason


def test_chat_search_demotes_assistant_no_result_messages():
    ranking = ChatSearchRanking()

    factual_score = ranking.score_text(
        "What did I say about my PC?",
        "I own an Omen PC forty five.",
        role="user",
    )
    no_result_score = ranking.score_text(
        "What did I say about my PC?",
        "I checked old chats, but nothing about your PC came up.",
        role="assistant",
    )

    assert factual_score.score > no_result_score.score
    assert "no-result demotion" in no_result_score.reason


def test_chat_search_scores_title_matches_for_chats_tab():
    ranking = ChatSearchRanking()

    title_score = ranking.score_text(
        "bakery",
        "Bakery planning",
        title_match=True,
    )
    message_score = ranking.score_text(
        "bakery",
        "I am heading to the bakery.",
        role="user",
    )

    assert title_score.score > message_score.score
