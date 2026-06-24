import re
from typing import Optional


MIN_PARTIAL_TERM_LENGTH = 4
MAX_SHORT_TOKEN_LENGTH = 2

ORDINAL_WORDS = {
    "first": "1",
    "second": "2",
    "third": "3",
    "fourth": "4",
    "fifth": "5",
    "sixth": "6",
    "seventh": "7",
    "eighth": "8",
    "ninth": "9",
    "tenth": "10",
    "eleventh": "11",
    "twelfth": "12",
    "thirteenth": "13",
    "fourteenth": "14",
    "fifteenth": "15",
    "sixteenth": "16",
    "seventeenth": "17",
    "eighteenth": "18",
    "nineteenth": "19",
    "twentieth": "20",
    "twentyfirst": "21",
    "twenty-first": "21",
    "twentysecond": "22",
    "twenty-second": "22",
    "twentythird": "23",
    "twenty-third": "23",
    "twentyfourth": "24",
    "twenty-fourth": "24",
    "twentyfifth": "25",
    "twenty-fifth": "25",
    "twentysixth": "26",
    "twenty-sixth": "26",
    "twentyseventh": "27",
    "twenty-seventh": "27",
    "twentyeighth": "28",
    "twenty-eighth": "28",
    "twentyninth": "29",
    "twenty-ninth": "29",
    "thirtieth": "30",
    "thirtyfirst": "31",
    "thirty-first": "31",
}
ORDINAL_NUMBERS = {number: word for word, number in ORDINAL_WORDS.items()}
CARDINAL_ONES = {
    "zero": 0,
    "one": 1,
    "two": 2,
    "three": 3,
    "four": 4,
    "five": 5,
    "six": 6,
    "seven": 7,
    "eight": 8,
    "nine": 9,
    "ten": 10,
    "eleven": 11,
    "twelve": 12,
    "thirteen": 13,
    "fourteen": 14,
    "fifteen": 15,
    "sixteen": 16,
    "seventeen": 17,
    "eighteen": 18,
    "nineteen": 19,
}
CARDINAL_TENS = {
    "twenty": 20,
    "thirty": 30,
    "forty": 40,
    "fifty": 50,
    "sixty": 60,
    "seventy": 70,
    "eighty": 80,
    "ninety": 90,
}


class ChatSearchTextNormalizer:
    def raw_terms(self, query: str) -> list[str]:
        return re.findall(r"[a-z0-9']+(?:-[a-z0-9']+)*", str(query or "").lower())

    def normalize_term(self, term: str) -> str:
        normalized = str(term or "").lower().strip("'")
        if normalized.endswith("'s"):
            normalized = normalized[:-2]
        return normalized

    def simple_term_variants(self, term: str) -> tuple[str, ...]:
        term = self.normalize_term(term)
        if not term:
            return ()
        variants = [term]
        ordinal_base = self.ordinal_base(term)
        if term.isdigit():
            number = str(int(term))
            variants.extend([number, self.ordinal_variant(number)])
            ordinal_word = ORDINAL_NUMBERS.get(number)
            if ordinal_word:
                variants.append(ordinal_word)
        elif self.model_code_base(term):
            variants.extend(self.model_code_variants(term))
        elif ordinal_base:
            variants.append(ordinal_base)
            ordinal_word = ORDINAL_NUMBERS.get(str(int(ordinal_base)))
            if ordinal_word:
                variants.append(ordinal_word)
        elif term in ORDINAL_WORDS:
            number = ORDINAL_WORDS[term]
            variants.extend([number, self.ordinal_variant(number)])

        variants.extend(sorted(self.inflection_variants(term)))
        return tuple(
            variant
            for variant in self.unique_terms(variants)
            if variant and self.is_searchable_variant(variant)
        )

    def inflection_variants(self, term: str) -> set[str]:
        variants: set[str] = set()
        if len(term) < 4 or self.numeric_or_ordinal(term):
            return variants
        if term.endswith("ies") and len(term) > 4:
            variants.add(f"{term[:-3]}y")
        elif term.endswith("ves") and len(term) > 4:
            variants.add(f"{term[:-3]}f")
            variants.add(f"{term[:-3]}fe")
        elif term.endswith("es") and len(term) > 4:
            variants.add(term[:-2])
            variants.add(term[:-1])
        elif term.endswith("s") and len(term) > 3:
            variants.add(term[:-1])
        else:
            variants.add(f"{term}s")
            if (
                term.endswith("y")
                and len(term) > 3
                and term[-2] not in {"a", "e", "i", "o", "u"}
            ):
                variants.add(f"{term[:-1]}ies")

        if term.endswith("ing") and len(term) > 5:
            base = term[:-3]
            variants.add(base)
            if len(base) > 3 and base[-1] == base[-2]:
                variants.add(base[:-1])
            if len(base) >= 3:
                variants.add(f"{base}e")
        if term.endswith("ed") and len(term) > 4:
            base = term[:-2]
            variants.add(base)
            if len(base) > 3 and base[-1] == base[-2]:
                variants.add(base[:-1])
            if len(base) >= 3:
                variants.add(f"{base}e")
            if base.endswith("i"):
                variants.add(f"{base[:-1]}y")
        return variants

    def normalize_text(self, text: str) -> str:
        normalized = str(text or "").lower()
        normalized = normalized.replace("-", " ")
        normalized = self.normalize_cardinal_number_words(normalized)
        normalized = re.sub(r"\b(\d+)\s+([a-z])\b", r"\1\2", normalized)
        return " ".join(normalized.split())

    def term_in_text(self, term: str, text: str) -> bool:
        normalized_term = self.normalize_term(self.normalize_text(term))
        if not normalized_term:
            return False
        return any(
            self.terms_match(normalized_term, token)
            for token in self.normalized_tokens(text)
        )

    def phrase_in_text(self, phrase: str, text: str) -> bool:
        phrase_terms = self.normalized_tokens(phrase)
        if not phrase_terms:
            return False
        text_terms = self.normalized_tokens(text)
        if len(phrase_terms) > len(text_terms):
            return False
        for start in range(0, len(text_terms) - len(phrase_terms) + 1):
            candidate = text_terms[start : start + len(phrase_terms)]
            if all(
                self.terms_match(expected, actual)
                for expected, actual in zip(phrase_terms, candidate)
            ):
                return True
        return False

    def normalized_tokens(self, text: str) -> list[str]:
        return [
            self.normalize_term(term)
            for term in self.raw_terms(self.normalize_text(text))
            if self.normalize_term(term)
        ]

    def is_searchable_short_term(self, term: str) -> bool:
        normalized = self.normalize_term(term)
        return (
            len(normalized) >= 3
            or self.is_acronym_like(normalized)
            or normalized.isdigit()
            or self.ordinal_base(normalized) is not None
        )

    def is_searchable_variant(self, term: str) -> bool:
        return self.is_searchable_short_term(term) or term in ORDINAL_WORDS

    def is_acronym_like(self, term: str) -> bool:
        return term.isalnum() and 1 < len(term) <= MAX_SHORT_TOKEN_LENGTH

    def numeric_or_ordinal(self, term: str) -> bool:
        return (
            term.isdigit()
            or self.ordinal_base(term) is not None
            or term in ORDINAL_WORDS
        )

    def terms_match(self, expected: str, actual: str) -> bool:
        expected = self.normalize_term(expected)
        actual = self.normalize_term(actual)
        if expected == actual:
            return True
        expected_model_parts = self.model_code_variants(expected)
        actual_model_parts = self.model_code_variants(actual)
        if expected in actual_model_parts or actual in expected_model_parts:
            return True
        expected_word_base = ORDINAL_WORDS.get(expected)
        actual_word_base = ORDINAL_WORDS.get(actual)
        if expected_word_base and actual == expected_word_base:
            return True
        if actual_word_base and expected == actual_word_base:
            return True
        if expected_word_base and actual_word_base == expected_word_base:
            return True
        expected_base = self.ordinal_base(expected)
        actual_base = self.ordinal_base(actual)
        if expected.isdigit() and actual_base == expected:
            return True
        if expected_base is not None and actual == expected_base:
            return True
        if expected_base is not None and actual_base == expected_base:
            return True
        if self.numeric_or_ordinal(expected) or self.numeric_or_ordinal(actual):
            return False
        expected_variants = self.simple_term_variants(expected)
        actual_variants = self.simple_term_variants(actual)
        if expected in actual_variants or actual in expected_variants:
            return True
        if (
            len(expected) >= MIN_PARTIAL_TERM_LENGTH
            and len(actual) >= MIN_PARTIAL_TERM_LENGTH
            and (expected.startswith(actual) or actual.startswith(expected))
        ):
            return True
        return False

    def normalize_cardinal_number_words(self, text: str) -> str:
        tokens = re.findall(r"[a-z0-9']+|[^a-z0-9']+", text)
        normalized: list[str] = []
        index = 0
        while index < len(tokens):
            token = tokens[index]
            if not re.fullmatch(r"[a-z0-9']+", token):
                normalized.append(token)
                index += 1
                continue
            word = token.strip("'")
            if word in CARDINAL_TENS:
                next_index = index + 1
                separator = ""
                if next_index < len(tokens) and not re.fullmatch(
                    r"[a-z0-9']+",
                    tokens[next_index],
                ):
                    separator = tokens[next_index]
                    next_index += 1
                if (
                    next_index < len(tokens)
                    and re.fullmatch(r"[a-z0-9']+", tokens[next_index])
                    and tokens[next_index].strip("'") in CARDINAL_ONES
                ):
                    value = CARDINAL_TENS[word] + CARDINAL_ONES[
                        tokens[next_index].strip("'")
                    ]
                    normalized.append(str(value))
                    index = next_index + 1
                    continue
                if (
                    next_index < len(tokens)
                    and re.fullmatch(r"[a-z0-9']+", tokens[next_index])
                    and tokens[next_index].strip("'") in ORDINAL_WORDS
                    and int(ORDINAL_WORDS[tokens[next_index].strip("'")]) < 10
                ):
                    value = CARDINAL_TENS[word] + int(
                        ORDINAL_WORDS[tokens[next_index].strip("'")]
                    )
                    normalized.append(str(value))
                    index = next_index + 1
                    continue
                normalized.append(str(CARDINAL_TENS[word]))
                if separator:
                    normalized.append(separator)
                    index += 2
                else:
                    index += 1
                continue
            if word in CARDINAL_ONES:
                normalized.append(str(CARDINAL_ONES[word]))
                index += 1
                continue
            normalized.append(token)
            index += 1
        return "".join(normalized)

    def model_code_base(self, term: str) -> Optional[re.Match[str]]:
        return re.fullmatch(r"([a-z]+)?(\d{1,4})([a-z]+)?", self.normalize_term(term))

    def model_code_variants(self, term: str) -> tuple[str, ...]:
        match = self.model_code_base(term)
        if match is None:
            return ()
        prefix, number, suffix = match.groups()
        variants = [str(int(number))]
        if prefix:
            variants.append(prefix)
            variants.append(f"{prefix}{int(number)}")
        if suffix:
            variants.append(suffix)
            variants.append(f"{int(number)}{suffix}")
        return tuple(self.unique_terms(variants))

    def ordinal_base(self, term: str) -> Optional[str]:
        match = re.fullmatch(r"(\d{1,2})(?:st|nd|rd|th)", term)
        return match.group(1) if match else None

    def ordinal_variant(self, term: str) -> str:
        try:
            number = int(term)
        except ValueError:
            return term
        if 10 <= number % 100 <= 20:
            suffix = "th"
        else:
            suffix = {1: "st", 2: "nd", 3: "rd"}.get(number % 10, "th")
        return f"{number}{suffix}"

    def unique_terms(self, terms: list[str]) -> list[str]:
        unique: list[str] = []
        for term in terms:
            if term and term not in unique:
                unique.append(term)
        return unique
