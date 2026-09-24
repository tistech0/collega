"""Calcul du coût € des tokens Claude — Story 7.8.

Fonction *pure* : le coût n'est JAMAIS persisté, il est recalculé à la lecture
depuis les compteurs `input_tokens`/`output_tokens` du `GenerationJob`. Ainsi un
changement de tarif Anthropic ou de taux €/$ n'invalide pas l'historique.

Tout le flux de génération de fiches passe par `claude-sonnet-4-6`
(`generate_cards_for_item`), un seul jeu de tarifs suffit donc ici.
"""

from __future__ import annotations

from app.core.config import settings

# Tarifs Anthropic claude-sonnet-4-6 (USD / 1M tokens) — vérifiés 2026-06-17.
_SONNET_INPUT_USD_PER_MTOK = 3.00
_SONNET_OUTPUT_USD_PER_MTOK = 15.00


def compute_cost_eur(input_tokens: int | None, output_tokens: int | None) -> float:
    """Coût € pour un volume de tokens Sonnet 4.6.

    `None` (job non mesuré) compte comme 0 — l'agrégation traite donc le legacy
    comme gratuit dans les totaux, ce qui est le comportement attendu (décision PL #2).
    """
    it = input_tokens or 0
    ot = output_tokens or 0
    usd = (it * _SONNET_INPUT_USD_PER_MTOK + ot * _SONNET_OUTPUT_USD_PER_MTOK) / 1_000_000
    return round(usd * settings.usd_eur_rate, 4)
