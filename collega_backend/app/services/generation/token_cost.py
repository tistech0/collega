"""Coût € des tokens Claude, tarif par modèle (story 7.8, chantier 4 spec § 6).

Le coût n'est JAMAIS persisté : il est recalculé à la lecture depuis les lignes
`claude_usage` (modèle + tokens). Un changement de tarif ou de taux €/$ ne fausse
donc jamais l'historique.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

from app.core.config import settings

logger = logging.getLogger(__name__)

# Tarifs Anthropic (USD / 1M tokens, entrée, sortie) — vérifiés le 2026-09-24.
# Une clé couvre aussi les identifiants datés qui la prolongent
# (« claude-haiku-4-5 » → « claude-haiku-4-5-20251001 »).
PRICES_USD_PER_MTOK: dict[str, tuple[float, float]] = {
    "claude-sonnet-4-6": (3.00, 15.00),
    "claude-sonnet-5": (2.00, 10.00),
    "claude-haiku-4-5": (1.00, 5.00),
}
FALLBACK_MODEL = "claude-sonnet-5"

_warned_models: set[str] = set()


def _prices(model: str) -> tuple[float, float]:
    if model in PRICES_USD_PER_MTOK:
        return PRICES_USD_PER_MTOK[model]
    for prefix in sorted(PRICES_USD_PER_MTOK, key=len, reverse=True):
        if model.startswith(prefix + "-"):
            return PRICES_USD_PER_MTOK[prefix]
    if model not in _warned_models:
        _warned_models.add(model)
        logger.warning("Tarif inconnu pour le modèle %s : tarif %s appliqué", model, FALLBACK_MODEL)
    return PRICES_USD_PER_MTOK[FALLBACK_MODEL]


def cost_usd(model: str, input_tokens: int | None, output_tokens: int | None) -> float:
    """Coût USD non arrondi (`None` compte comme 0)."""
    usd_in, usd_out = _prices(model)
    return ((input_tokens or 0) * usd_in + (output_tokens or 0) * usd_out) / 1_000_000


def compute_cost_eur(model: str, input_tokens: int | None, output_tokens: int | None) -> float:
    """Coût € arrondi à 4 décimales pour un volume de tokens d'un modèle."""
    return round(cost_usd(model, input_tokens, output_tokens) * settings.usd_eur_rate, 4)


@dataclass
class UsageTotals:
    """Cumul de lignes de modèles différents ; le coût est arrondi une seule fois, à la fin."""

    input_tokens: int = 0
    output_tokens: int = 0
    usd: float = 0.0

    def add(self, model: str, input_tokens: int, output_tokens: int) -> None:
        self.input_tokens += input_tokens
        self.output_tokens += output_tokens
        self.usd += cost_usd(model, input_tokens, output_tokens)

    @property
    def cost_eur(self) -> float:
        return round(self.usd * settings.usd_eur_rate, 4)
