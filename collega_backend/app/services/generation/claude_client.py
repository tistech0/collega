from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass
from typing import Any

import anthropic

from app.core.config import settings
from app.schemas.college import FlashCardData as FlashCardDataSchema

logger = logging.getLogger(__name__)

GENERATION_MODEL = "claude-sonnet-4-6"
# Incrémenter à chaque changement de GENERATION_PROMPT : les items déjà vus seront
# régénérés (clé des item_generations = empreinte + version), sans effacer les anciennes.
PROMPT_VERSION = "p1"
GENERATION_VERSION = f"{GENERATION_MODEL}:{PROMPT_VERSION}"

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


REGENERATION_PROMPT = """
Tu es un expert en fiches de révision médicale ECNi.
La fiche suivante a été jugée non pertinente par un étudiant.

Fiche originale :
- Type : {card_type}
- Recto : {recto}
- Verso : {verso}
- Item : {item_number} (Rang {rang})

Feedback de l'étudiant : {user_note}

Texte OCR source :
{ocr_text}

Régénère UNE fiche améliorée du même type (classique ou définition) en tenant compte du feedback.

Réponds UNIQUEMENT avec un objet JSON valide, sans markdown :
{{"type": "{card_type}", "recto": "Question améliorée ?", "verso": "Réponse améliorée"}}
"""


@dataclass
class FlashCardData:
    card_type: str
    recto: str
    verso: str


@dataclass
class CardGenResult:
    """Résultat d'un appel `generate_cards` : fiches + usage tokens.

    L'usage est porté par le résultat (et non un état partagé) pour qu'il
    *survive* à un échec de parsing JSON : l'appel API a déjà facturé les tokens
    même si la réponse est mal formée (Story 7.8 AC1).
    """

    cards: list[FlashCardData]
    input_tokens: int
    output_tokens: int


class ClaudeClient:
    def __init__(self) -> None:
        self._client = anthropic.AsyncAnthropic(
            api_key=settings.claude_api_key,
            max_retries=3,
        )

    async def ask_json(self, prompt: str) -> dict:
        message = await self._client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=256,
            messages=[{"role": "user", "content": prompt}],
        )
        if not message.content or message.content[0].type != "text":
            raise ValueError("Unexpected Claude response structure")
        text = message.content[0].text
        start = text.find("{")
        end = text.rfind("}") + 1
        if start == -1 or end <= start:
            raise ValueError(f"No JSON object in Claude response: {text!r}")
        return json.loads(text[start:end])

    async def generate_cards(self, item_number: int, rang: str, text: str) -> CardGenResult:
        """Génère les fiches d'un item à partir de son texte (sortie d'origine,
        stockée dans item_generations par le pipeline)."""
        if not text.strip():
            logger.warning("Item %s sans texte — pas d'appel Claude", item_number)
            return CardGenResult(cards=[], input_tokens=0, output_tokens=0)

        # str.format n'interprète pas les accolades des valeurs insérées : le texte
        # est transmis tel quel (l'ancien échappement « { → {{ » l'altérait).
        prompt = GENERATION_PROMPT.format(item_number=item_number, rang=rang, ocr_text=text)

        # anthropic.APIError se propage (pas de réponse → aucun usage à compter,
        # le worker marquera le job 'failed').
        response = await self._client.messages.create(
            model=GENERATION_MODEL,
            max_tokens=2000,
            messages=[{"role": "user", "content": prompt}],
        )
        # Capturer l'usage AVANT le parsing : les tokens sont facturés même si la
        # réponse JSON est invalide (Story 7.8 AC1 — le coût doit survivre au except).
        input_tokens = response.usage.input_tokens
        output_tokens = response.usage.output_tokens

        try:
            raw = response.content[0].text.strip()  # type: ignore[union-attr]
            # Strip markdown code fence if Claude wraps JSON in ```json ... ```
            if raw.startswith("```"):
                raw = re.sub(r"^```[a-z]*\n?", "", raw)
                raw = re.sub(r"\n?```$", "", raw)
                raw = raw.strip()
            data = json.loads(raw)
        except (json.JSONDecodeError, KeyError, IndexError, AttributeError) as exc:
            # AttributeError : content[0] peut être un bloc non-texte (refus/thinking)
            # sans `.text` → dégrader en cards=[] avec usage préservé (cf. ask_json qui
            # garde déjà ce cas), plutôt que de laisser l'exception crasher l'item.
            logger.error("Failed to parse Claude response for item %s: %s", item_number, exc)
            return CardGenResult(cards=[], input_tokens=input_tokens, output_tokens=output_tokens)

        cards: list[FlashCardData] = []
        for entry in data.get("flashcards", []):
            card_type = entry.get("type", "")
            if card_type not in ("classique", "definition"):
                continue
            recto = entry.get("recto", "").strip()
            verso = entry.get("verso", "").strip()
            if recto and verso:
                cards.append(FlashCardData(card_type=card_type, recto=recto, verso=verso))

        return CardGenResult(cards=cards, input_tokens=input_tokens, output_tokens=output_tokens)

    async def regenerate_single_card(
        self,
        card: Any,
        item: Any,
        source_text: str,
        user_note: str | None,
    ) -> FlashCardDataSchema | None:
        """Régénère une seule fiche avec le feedback utilisateur en contexte."""
        if not source_text.strip():
            logger.warning("Item %s sans texte source — impossible de régénérer la fiche %s", item.id, card.id)
            return None

        prompt = REGENERATION_PROMPT.format(
            card_type=card.card_type,
            recto=card.recto,
            verso=card.verso,
            item_number=item.item_number,
            rang=item.rang,
            user_note=user_note or "Aucun commentaire spécifique",
            ocr_text=source_text,
        )

        try:
            response = await self._client.messages.create(
                model=GENERATION_MODEL,
                max_tokens=500,
                messages=[{"role": "user", "content": prompt}],
            )
            raw = response.content[0].text.strip()  # type: ignore[union-attr]
            if raw.startswith("```"):
                raw = re.sub(r"^```[a-z]*\n?", "", raw)
                raw = re.sub(r"\n?```$", "", raw)
                raw = raw.strip()
            data = json.loads(raw)
        except (anthropic.APIError, json.JSONDecodeError, KeyError, IndexError) as exc:
            logger.error("Failed to regenerate card %s: %s", card.id, exc)
            return None

        recto = data.get("recto", "").strip()
        verso = data.get("verso", "").strip()
        if not recto or not verso:
            return None
        return FlashCardDataSchema(
            id=str(card.id),
            item_id=str(card.item_id),
            college_id=str(card.college_id),
            card_type=data.get("type", card.card_type),
            rang=card.rang,
            recto=recto,
            verso=verso,
            ocr_confidence_score=card.ocr_confidence_score,
            low_confidence=card.low_confidence,
        )
