"""Tests de compute_cost_eur — fonction pure de coût € des tokens (Story 7.8 AC4)."""

from __future__ import annotations

from app.core.config import settings
from app.services.generation.token_cost import compute_cost_eur


class TestComputeCostEur:
    def test_zero_tokens_is_zero(self):
        assert compute_cost_eur(0, 0) == 0.0

    def test_none_tokens_counts_as_zero(self):
        """Un job non mesuré (NULL) → 0 € (décision PL #2)."""
        assert compute_cost_eur(None, None) == 0.0
        assert compute_cost_eur(None, 500) == compute_cost_eur(0, 500)

    def test_known_values_with_default_rate(self):
        """1M in + 1M out = (3 + 15) USD × 0.92 = 16.56 €."""
        # On suppose le taux par défaut 0.92 du config.py.
        assert settings.usd_eur_rate == 0.92
        cost = compute_cost_eur(1_000_000, 1_000_000)
        assert cost == round((3.00 + 15.00) * 0.92, 4)
        assert cost == 16.56

    def test_input_and_output_priced_differently(self):
        """Output 5× plus cher que l'input (15 vs 3 USD/MTok)."""
        in_only = compute_cost_eur(1_000_000, 0)
        out_only = compute_cost_eur(0, 1_000_000)
        assert round(out_only / in_only, 2) == 5.0

    def test_rate_is_configurable(self, monkeypatch):
        monkeypatch.setattr(settings, "usd_eur_rate", 1.0)
        # 1M out = 15 USD × 1.0 = 15.0 €
        assert compute_cost_eur(0, 1_000_000) == 15.0
