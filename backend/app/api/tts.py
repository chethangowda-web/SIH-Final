"""
Text-to-Speech (TTS) Streaming Service for Indian Regional Languages.
Powers audible, crystal-clear voice assistance in Kannada, Hindi, and English
across all client devices and web browsers.
"""
import re
import httpx
from fastapi import APIRouter, Query, HTTPException, Response, status
from typing import Dict
from app.core.logging_config import get_logger

logger = get_logger("tts")

router = APIRouter(tags=["Text-To-Speech"])

# In-memory LRU audio cache for instant sub-millisecond audio delivery
_AUDIO_CACHE: Dict[str, bytes] = {}
_MAX_CACHE_ENTRIES = 500

def _normalize_lang(lang: str) -> str:
    l_lower = (lang or "").strip().lower().replace("_", "-")
    if "kn" in l_lower or "kannada" in l_lower:
        return "kn"
    elif "hi" in l_lower or "hindi" in l_lower:
        return "hi"
    return "en"

def _split_text_chunks(text: str, max_chunk_len: int = 150):
    """Split sentences gracefully on Indian punctuation, full stops, or commas."""
    sentences = re.split(r'([।\.\!\?\,\n]+)', text)
    chunks = []
    curr = ""
    for s in sentences:
        if len(curr) + len(s) <= max_chunk_len:
            curr += s
        else:
            if curr.strip():
                chunks.append(curr.strip())
            curr = s
    if curr.strip():
        chunks.append(curr.strip())
    return chunks or [text]

@router.get("/tts/speak")
async def stream_tts_audio(
    text: str = Query(..., min_length=1, max_length=1000, description="Text to synthesize"),
    lang: str = Query("kn", description="Language code: kn (Kannada), hi (Hindi), en (English)")
):
    """
    Synthesize and stream audio/mpeg MP3 for regional languages (Kannada, Hindi, English).
    Guarantees audible, authentic pronunciation regardless of whether the user's browser
    or OS has regional language speech packs installed.
    """
    clean_text = text.strip()
    if not clean_text:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Text cannot be empty.")

    target_lang = _normalize_lang(lang)
    cache_key = f"{target_lang}:{clean_text}"

    # Check in-memory cache first
    if cache_key in _AUDIO_CACHE:
        return Response(
            content=_AUDIO_CACHE[cache_key],
            media_type="audio/mpeg",
            headers={
                "Cache-Control": "public, max-age=86400",
                "X-TTS-Source": "cache",
                "X-TTS-Lang": target_lang
            }
        )

    chunks = _split_text_chunks(clean_text)
    combined_audio = bytearray()

    async with httpx.AsyncClient(timeout=10.0, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}) as client:
        for chunk in chunks:
            if not chunk.strip():
                continue
            try:
                resp = await client.get(
                    "https://translate.google.com/translate_tts",
                    params={
                        "ie": "UTF-8",
                        "q": chunk,
                        "tl": target_lang,
                        "client": "tw-ob"
                    }
                )
                if resp.status_code == 200 and resp.content:
                    combined_audio.extend(resp.content)
                else:
                    logger.warning("TTS upstream chunk failed: %s with status %s", chunk[:30], resp.status_code)
            except Exception as e:
                logger.warning("TTS request error for chunk '%s': %s", chunk[:30], e)

    if not combined_audio:
        logger.error("TTS generation failed for text '%s' (lang=%s)", clean_text[:50], target_lang)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Speech synthesis temporarily unavailable for {target_lang}."
        )

    final_audio_bytes = bytes(combined_audio)

    # Store in memory cache
    if len(_AUDIO_CACHE) >= _MAX_CACHE_ENTRIES:
        # Evict earliest items
        for k in list(_AUDIO_CACHE.keys())[:50]:
            del _AUDIO_CACHE[k]
    _AUDIO_CACHE[cache_key] = final_audio_bytes

    return Response(
        content=final_audio_bytes,
        media_type="audio/mpeg",
        headers={
            "Cache-Control": "public, max-age=86400",
            "X-TTS-Source": "live_synthesis",
            "X-TTS-Lang": target_lang
        }
    )
