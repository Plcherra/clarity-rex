"""Experimental layered Rex Brain config.

MVP production chat and voice use ChatService + SimpleRexBrain.
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class RexThinkingRouterConfig:
    deep_score_threshold: int = 6
    max_fast_words: int = 20
    max_fast_message_length: int = 240
    voice_deep_score_threshold: int = 8
