from app.services.merchant_match_query import (
    merchant_match_query,
    merchant_match_terms,
)


def test_a_plural_the_user_said_reaches_the_singular_on_the_statement():
    """The reported miss: "sultanas" never found "El Valle De La Sultana"."""
    assert merchant_match_terms("sultanas") == ["sultana"]
    assert merchant_match_query("sultanas") == {
        "or": '(description.ilike."*sultana*",merchant.ilike."*sultana*")'
    }


def test_articles_drop_out_so_a_spoken_name_reaches_a_printed_one():
    assert merchant_match_terms("El Valle De La Sultana") == ["valle", "sultana"]


def test_card_noise_is_never_a_term_a_row_has_to_contain():
    assert merchant_match_terms("CHECKCARD 0718 Bom Dough") == ["bom", "dough"]


def test_every_term_must_appear_when_the_name_has_several_words():
    query = merchant_match_query("bom dough")
    assert query == {
        "and": (
            '(or(description.ilike."*bom*",merchant.ilike."*bom*"),'
            'or(description.ilike."*dough*",merchant.ilike."*dough*"))'
        )
    }


def test_a_long_statement_line_is_capped_so_it_can_still_match_something():
    terms = merchant_match_terms(
        "CHECKCARD 0718 MINEIRAO ONE STOP MART SOMERVILLE MA XXXXX3961XXXX9301"
    )
    assert len(terms) <= 4
    assert terms[0] == "mineirao"


def test_a_double_s_name_keeps_its_ending():
    assert merchant_match_terms("Express") == ["express"]


def test_a_name_made_only_of_short_words_still_matches_itself():
    assert merchant_match_terms("BJs") == ["bjs"]


def test_nothing_to_match_returns_no_query():
    assert merchant_match_query("") is None
    assert merchant_match_query(None) is None
