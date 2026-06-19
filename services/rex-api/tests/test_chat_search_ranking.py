from app.services.chat_search_ranking import ChatSearchRanking


def test_chat_search_expands_arbitrary_recall_topics():
    ranking = ChatSearchRanking()

    assert "ead" in ranking.expand_terms("What did I say about immigration?")
    assert "buying" in ranking.expand_terms("Search chats for purchases")
    assert "computer" in ranking.expand_terms("What did I say about my PC?")
    assert "send" in ranking.expand_terms("Did I mention giving her a gift?")
    assert "buying" in ranking.expand_terms("What was the game I wanted to buy?")


def test_chat_search_builds_subject_and_expanded_queries():
    ranking = ChatSearchRanking()

    queries = ranking.build_queries("Do you know anything about my mom?")

    assert [query.mode for query in queries] == [
        "exact",
        "expanded_keywords",
        "keyword",
        "keyword",
        "keyword",
        "keyword",
    ]
    assert queries[1].query == "mom mother mum mama"
    assert [query.query for query in queries[2:6]] == [
        "mom",
        "mother",
        "mum",
        "mama",
    ]


def test_chat_search_keeps_full_query_terms_when_subject_exists():
    ranking = ChatSearchRanking()

    queries = ranking.build_queries("What did I say about my PC game?")

    expanded = queries[1].query.split()
    assert "pc" in expanded
    assert "computer" in expanded
    assert "game" in expanded


def test_chat_search_expands_buying_recall_without_subject_phrase():
    ranking = ChatSearchRanking()

    queries = ranking.build_queries("What was the game I wanted to buy?")

    expanded = queries[1].query.split()
    assert "game" in expanded
    assert "buying" in expanded
    assert "purchase" in expanded


def test_chat_search_scores_user_exact_match_above_assistant_noise():
    ranking = ChatSearchRanking()

    user_score = ranking.score_text(
        "What did I say about immigration?",
        "My EAD renewal and USCIS immigration paperwork are due soon.",
        role="user",
    )
    assistant_score = ranking.score_text(
        "What did I say about immigration?",
        "I searched chats, but nothing about immigration came up.",
        role="assistant",
    )

    assert user_score.score > assistant_score.score
    assert "ead" in user_score.matched_terms


def test_chat_search_scores_title_matches_for_chats_tab():
    ranking = ChatSearchRanking()

    title_score = ranking.score_text(
        "work",
        "Work stress",
        title_match=True,
    )
    message_score = ranking.score_text(
        "work",
        "I am stressed about work.",
        role="user",
    )

    assert title_score.score > message_score.score
