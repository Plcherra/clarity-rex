#!/usr/bin/env python3
"""Translate app_es.arb from app_en.arb for Phase L1 (neutral LATAM Spanish).

Preserves ICU plural/select syntax and {placeholder} tokens.
Keeps existing Spanish entries that differ from English.
"""
from __future__ import annotations

import json
import re
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EN_PATH = ROOT / "lib/l10n/app_en.arb"
ES_PATH = ROOT / "lib/l10n/app_es.arb"

# Do not translate product / protocol names.
KEEP_LITERAL = frozenset(
    {
        "Clarity",
        "Rex",
        "Plaid",
        "Zelle",
        "CSV",
        "UTF-8",
        "iOS",
        "USD",
        "AI",
        "STT",
        "TTS",
        "LLM",
        "MFA",
        "API",
    }
)

TOKEN_PATTERN = re.compile(
    r"\{[^{}]+\}|\{[^{}]*,\s*plural,\s*(?:[^{}]|\{[^{}]*\})*\}"
    r"|\{[^{}]*,\s*select,\s*(?:[^{}]|\{[^{}]*\})*\}"
)

# ICU keywords must stay English inside plural/select blocks.
ICU_KEYWORD_FIXES = (
    (re.compile(r"\brecuento\b", re.I), "count"),
    (re.compile(r"\botro\b", re.I), "other"),
    (re.compile(r"\buno\b", re.I), "one"),
    (re.compile(r"\bseleccionar\b", re.I), "select"),
)


def fix_icu_keywords(text: str) -> str:
    if "plural" not in text and "select" not in text:
        return text
    fixed = text
    for pattern, replacement in ICU_KEYWORD_FIXES:
        fixed = pattern.sub(replacement, fixed)
    return fixed

# Manual overrides for tone-sensitive or already-reviewed copy.
MANUAL_ES: dict[str, str] = {
    "commonCustom": "Personalizado",
    "chatPageDefaultTitle": "Rex",
    "assistantTabChat": "Chat",
    "assistantTabChats": "Chats",
    "assistantTabOverview": "Resumen",
    "usageAdminRadarChatLlm": "Chat LLM",
    "usageAdminRadarVoiceLlm": "Voz LLM",
    "usageAdminRadarSttMin": "STT min",
    "usageAdminRadarTtsMin": "TTS min",
}


def load_arb(path: Path) -> dict:
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def save_arb(path: Path, data: dict) -> None:
    ordered: dict = {"@@locale": data.get("@@locale", "es")}
    for key in sorted(k for k in data if not k.startswith("@@")):
        if key.startswith("@"):
            continue
        ordered[key] = data[key]
        meta = f"@{key}"
        if meta in data:
            ordered[meta] = data[meta]
    for key, value in data.items():
        if key.startswith("@") and key[1:] not in ordered:
            ordered[key] = value
    with path.open("w", encoding="utf-8", newline="\n") as f:
        json.dump(ordered, f, indent=2, ensure_ascii=False)
        f.write("\n")


def protect_tokens(text: str) -> tuple[str, list[str]]:
    tokens: list[str] = []

    def repl(match: re.Match[str]) -> str:
        tokens.append(match.group(0))
        return f"__TOK{len(tokens) - 1}__"

    protected = TOKEN_PATTERN.sub(repl, text)
    return protected, tokens


def restore_tokens(text: str, tokens: list[str]) -> str:
    restored = text
    for index, token in enumerate(tokens):
        restored = restored.replace(f"__TOK{index}__", token)
        restored = restored.replace(f"__tok{index}__", token)
    return restored


def translate_chunk(text: str, translator) -> str:
    if not text.strip():
        return text
    protected, tokens = protect_tokens(text)
    try:
        translated = translator.translate(protected)
    except Exception:
        return text
    return fix_icu_keywords(restore_tokens(translated, tokens))


def get_translator():
    try:
        from deep_translator import GoogleTranslator

        return GoogleTranslator(source="en", target="es")
    except ImportError:
        return None


def should_skip_translation(key: str, en_value: str, es_value: str) -> bool:
    if key in MANUAL_ES:
        return True
    if es_value != en_value:
        return True
    return False


def build_es_arb(use_api: bool = True) -> None:
    en = load_arb(EN_PATH)
    existing = load_arb(ES_PATH) if ES_PATH.exists() else {}
    translator = get_translator() if use_api else None

    es_out: dict = {"@@locale": "es"}
    keys = sorted(k for k in en if not k.startswith("@"))

    translated_count = 0
    kept_count = 0
    cache: dict[str, str] = {}

    for key in keys:
        en_value = en[key]
        if not isinstance(en_value, str):
            es_out[key] = en_value
            continue

        if key in MANUAL_ES:
            es_out[key] = MANUAL_ES[key]
            kept_count += 1
        elif existing.get(key) not in (None, en_value) and existing.get(key) != en_value:
            es_out[key] = existing[key]
            kept_count += 1
        elif translator is None:
            es_out[key] = en_value
        else:
            if en_value in cache:
                es_out[key] = cache[en_value]
            else:
                es_out[key] = translate_chunk(en_value, translator)
                cache[en_value] = es_out[key]
                translated_count += 1
                if translated_count % 25 == 0:
                    time.sleep(0.3)
        meta = f"@{key}"
        if meta in en:
            es_out[meta] = en[meta]

    save_arb(ES_PATH, es_out)
    print(
        f"Wrote {ES_PATH.name}: {translated_count} translated, "
        f"{kept_count} kept, {len(keys)} total keys"
    )


if __name__ == "__main__":
    build_es_arb()
