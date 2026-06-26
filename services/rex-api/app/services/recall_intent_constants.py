"""Shared recall intent constants and compiled patterns."""

from __future__ import annotations

import re

PROFILE_MEMORY_QUERY = (
    "user profile identity facts preferences saved knowledge personal details"
)
MEMORY_INVENTORY_QUERY = (
    f"{PROFILE_MEMORY_QUERY} people relationships plans goals commitments "
    "personal rules memories chats conversations"
)
PROFILE_MEMORY_LIMIT = 4
RECALL_TRIGGER_PHRASES = (
    "chat history",
    "conversation history",
    "dig up",
    "look back",
    "old chat",
    "old chats",
    "past chat",
    "past chats",
    "previous chat",
    "previous chats",
    "pull up",
)
RECALL_FOLLOWUP_TERMS = (
    "by when",
    "for what",
    "that",
    "there",
    "it",
    "her",
    "him",
    "them",
    "this",
    "details",
    "mention",
    "mentioned",
    "the chat",
    "old chat",
    "old chats",
    "how much",
    "what amount",
    "what date",
    "what else",
    "why",
)
ROUTER_RECALL_QUESTION_TERMS = (
    "anything about me",
    "do you know anything",
    "do you know my",
    "do you know where",
    "do you remember",
    "what information do you have",
    "what information",
    "what do you remember",
    "what do you know",
    "what are my plans",
    "what city",
    "what rex knows",
    "what is my",
    "where i am",
    "where i'm",
    "where i'm located",
    "where do i live",
    "where am i",
)
ROUTER_RECALL_ACTION_TERMS = (
    "chat",
    "chats",
    "conversation",
    "conversations",
    "do you have",
    "do you know",
    "do you remember",
    "have i told you",
    "have we talked",
    "remember",
    "search",
    "talked about",
    "tell me what",
    "what did i tell you",
    "what do you have",
    "what do you know",
    "what do you remember",
    "what have i told you",
    "what have we talked",
    "what information",
)
USER_SCOPED_RECALL_TERMS = (
    " about me",
    " about my ",
    " i ",
    " i'm ",
    " me ",
    " my ",
    " our ",
    " us ",
    " we ",
)
FINANCE_ONLY_TERMS = (
    "account",
    "accounts",
    "balance",
    "balances",
    "bank",
    "budget",
    "budgets",
    "merchant",
    "merchants",
    "plaid",
    "spend",
    "spending",
    "spent",
    "transaction",
    "transactions",
)
CHAT_SCOPE_TERMS = (
    "chat",
    "chats",
    "conversation",
    "conversations",
    "history",
    "mentioned",
    "old",
    "past",
    "previous",
    "said",
    "talked",
    "told",
)
FOCUSED_DEFINITE_REFERENCE_PATTERN = re.compile(
    r"\b(?:the|those|these)\s+[a-z0-9']+(?:\s+[a-z0-9']+){0,3}\b"
)
FOCUSED_RELATIVE_REFERENCE_PATTERN = re.compile(
    r"\b([a-z0-9']+)\s+i\s+([a-z0-9']+)\b"
)
FOCUSED_MODAL_BEFORE_I = frozenset(
    {
        "am",
        "are",
        "can",
        "could",
        "did",
        "do",
        "does",
        "had",
        "has",
        "have",
        "how",
        "is",
        "may",
        "might",
        "must",
        "shall",
        "should",
        "was",
        "were",
        "what",
        "when",
        "where",
        "which",
        "who",
        "why",
        "will",
        "would",
        "thought",
        "said",
        "told",
        "mentioned",
        "meant",
        "mean",
    }
)
FOCUSED_TRAILING_USER_CLAUSE_PATTERN = re.compile(
    r"\s+(?:i|ai)\s+(?:bought|purchased|got|gotten|downloaded|installed|"
    r"owned|ordered|grabbed|picked up|wanted|said|told|mentioned|play|"
    r"played|get).*$"
)
RECALL_QUERY_NOISE_TERMS = frozenset(
    {
        "ai",
        "dont",
        "don't",
        "earlier",
        "know",
        "remember",
        "said",
        "thought",
        "you",
    }
)
