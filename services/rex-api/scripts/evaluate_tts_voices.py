"""Synthesize Rex voice samples for comparing masculine Google TTS options."""

from __future__ import annotations

import argparse
import asyncio
import base64
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import httpx

from app.config import Settings, get_settings
from app.services.google_tts_service import GoogleTTSService

SAMPLE_TEXT = (
    "Your spending is on track. Here is what I would focus on next."
)


@dataclass(frozen=True)
class VoiceCandidate:
    voice_name: str
    speaking_rate: float
    pitch: float
    volume_gain_db: float = 10.0

    @property
    def slug(self) -> str:
        voice = self.voice_name.replace("en-US-", "").replace("-", "_").lower()
        pitch = str(self.pitch).replace("-", "neg").replace(".", "p")
        rate = str(self.speaking_rate).replace(".", "p")
        return f"{voice}_rate{rate}_pitch{pitch}"


CANDIDATES: tuple[VoiceCandidate, ...] = (
    VoiceCandidate("en-US-Neural2-J", speaking_rate=1.25, pitch=0.0),
    VoiceCandidate("en-US-Neural2-D", speaking_rate=1.25, pitch=0.0),
    VoiceCandidate("en-US-Neural2-A", speaking_rate=1.25, pitch=0.0),
    VoiceCandidate("en-US-Studio-M", speaking_rate=1.10, pitch=0.0),
    VoiceCandidate("en-US-Neural2-J", speaking_rate=1.10, pitch=-1.5),
    VoiceCandidate("en-US-Neural2-D", speaking_rate=1.10, pitch=-1.5),
    VoiceCandidate("en-US-Neural2-J", speaking_rate=1.08, pitch=-2.0),
)


async def synthesize_candidate(
    service: GoogleTTSService,
    settings: Settings,
    candidate: VoiceCandidate,
    text: str,
) -> bytes:
    access_token = await service._access_token()
    payload = {
        "input": {"text": text},
        "voice": {
            "languageCode": settings.google_tts_language_code,
            "name": candidate.voice_name,
        },
        "audioConfig": {
            "audioEncoding": settings.google_tts_audio_encoding,
            "speakingRate": candidate.speaking_rate,
            "pitch": candidate.pitch,
            "volumeGainDb": candidate.volume_gain_db,
        },
    }

    async with httpx.AsyncClient(timeout=settings.google_tts_timeout_seconds) as client:
        response = await client.post(
            settings.google_tts_synthesize_url,
            headers={
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json; charset=utf-8",
                "x-goog-user-project": settings.google_tts_project_id or "",
            },
            json=payload,
        )
        response.raise_for_status()
        data = response.json()

    audio_base64 = data.get("audioContent")
    if not isinstance(audio_base64, str) or not audio_base64.strip():
        raise RuntimeError(f"No audio returned for {candidate.voice_name}")

    return base64.b64decode(audio_base64)


async def run(output_dir: Path, text: str) -> list[tuple[VoiceCandidate, Path]]:
    settings = get_settings()
    if not settings.google_tts_is_configured:
        raise SystemExit(
            "Google TTS is not configured. Set GOOGLE_TTS_PROJECT_ID and credentials."
        )

    service = GoogleTTSService(settings)
    output_dir.mkdir(parents=True, exist_ok=True)
    written: list[tuple[VoiceCandidate, Path]] = []

    for candidate in CANDIDATES:
        target = output_dir / f"{candidate.slug}.mp3"
        try:
            audio = await synthesize_candidate(service, settings, candidate, text)
        except httpx.HTTPStatusError as error:
            detail = error.response.text.strip()
            print(f"SKIP {candidate.voice_name}: {error.response.status_code} {detail}")
            continue

        target.write_bytes(audio)
        written.append((candidate, target))
        print(f"WROTE {target.name} voice={candidate.voice_name} rate={candidate.speaking_rate} pitch={candidate.pitch}")

    return written


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("tmp/tts_voice_eval"),
        help="Directory for generated MP3 samples",
    )
    parser.add_argument(
        "--text",
        default=SAMPLE_TEXT,
        help="Sample line to synthesize",
    )
    args = parser.parse_args()
    asyncio.run(run(args.output_dir, args.text.strip()))


if __name__ == "__main__":
    main()
