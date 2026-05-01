from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass

import anthropic

from app.core.config import settings

logger = logging.getLogger(__name__)

GENERATION_PROMPT = """
Tu es un expert en fiches de révision médicale ECNi.
Génère des flashcards à partir du texte OCR suivant pour l'Item {item_number} (Rang {rang}).

Texte OCR:
{ocr_text}

Génère des flashcards utiles pour réviser cet item :
- Des flashcards classiques : question médicale précise → réponse courte et factuelle
- Des fiches définition si le texte contient des termes médicaux à définir (terme → définition)

Réponds UNIQUEMENT avec un objet JSON valide, sans markdown, sans explication :
{{
  "flashcards": [
    {{"type": "classique", "recto": "Question médicale ?", "verso": "Réponse factuelle"}},
    {{"type": "definition", "recto": "Terme médical", "verso": "Définition clinique"}}
  ]
}}

Génère entre 2 et 5 flashcards classiques et 0 à 3 fiches définition selon le contenu.
"""


@dataclass
class FlashCardData:
    card_type: str
    recto: str
    verso: str


class ClaudeClient:
    def __init__(self) -> None:
        self._client = anthropic.AsyncAnthropic(
            api_key=settings.claude_api_key,
            max_retries=3,
        )

    async def generate_cards_for_item(self, item) -> list[FlashCardData]:
        if not item.ocr_text:
            logger.warning("Item %s has no ocr_text — skipping Claude call", item.id)
            return []

        # Escape braces in OCR text to prevent str.format() KeyError/IndexError
        safe_ocr_text = item.ocr_text.replace("{", "{{").replace("}", "}}")
        prompt = GENERATION_PROMPT.format(
            item_number=item.item_number,
            rang=item.rang,
            ocr_text=safe_ocr_text,
        )

        try:
            response = await self._client.messages.create(
                model="claude-sonnet-4-6",
                max_tokens=2000,
                messages=[{"role": "user", "content": prompt}],
            )
            raw = response.content[0].text.strip()
            # Strip markdown code fence if Claude wraps JSON in ```json ... ```
            if raw.startswith("```"):
                raw = re.sub(r"^```[a-z]*\n?", "", raw)
                raw = re.sub(r"\n?```$", "", raw)
                raw = raw.strip()
            data = json.loads(raw)
        except anthropic.APIError:
            raise
        except (json.JSONDecodeError, KeyError, IndexError) as exc:
            logger.error("Failed to parse Claude response for item %s: %s", item.id, exc)
            return []

        cards: list[FlashCardData] = []
        for entry in data.get("flashcards", []):
            card_type = entry.get("type", "")
            if card_type not in ("classique", "definition"):
                continue
            recto = entry.get("recto", "").strip()
            verso = entry.get("verso", "").strip()
            if recto and verso:
                cards.append(FlashCardData(card_type=card_type, recto=recto, verso=verso))

        return cards
