"""Tests de compute_cost_eur — coût € des tokens, tarif par modèle (chantier 4, spec § 6)."""

from __future__ import annotations

import logging

import pytest

from app.core.config import settings
from app.services.generation import token_cost
from app.services.generation.token_cost import compute_cost_eur


class TestComputeCostEur:
    def test_zero_tokens_is_zero(self):
        assert compute_cost_eur("claude-sonnet-5", 0, 0) == 0.0

    def test_none_tokens_counts_as_zero(self):
        assert compute_cost_eur("claude-sonnet-5", None, None) == 0.0
        assert compute_cost_eur("claude-sonnet-5", None, 500) == compute_cost_eur("claude-sonnet-5", 0, 500)

    @pytest.mark.parametrize(
        ("model", "usd_in", "usd_out"),
        [
            ("claude-sonnet-4-6", 3.00, 15.00),
            ("claude-sonnet-5", 2.00, 10.00),
            ("claude-haiku-4-5", 1.00, 5.00),
            ("claude-haiku-4-5-20251001", 1.00, 5.00),
        ],
    )
    def test_price_per_model(self, model, usd_in, usd_out):
        assert settings.usd_eur_rate == 0.92
        assert compute_cost_eur(model, 1_000_000, 0) == round(usd_in * 0.92, 4)
        assert compute_cost_eur(model, 0, 1_000_000) == round(usd_out * 0.92, 4)

    def test_sonnet_4_6_known_value(self):
        """1M in + 1M out Sonnet 4.6 = (3 + 15) USD × 0.92 = 16.56 €."""
        assert compute_cost_eur("claude-sonnet-4-6", 1_000_000, 1_000_000) == 16.56

    def test_unknown_model_priced_as_sonnet_5_with_warning(self, caplog, monkeypatch):
        monkeypatch.setattr(token_cost, "_warned_models", set())
        with caplog.at_level(logging.WARNING, logger=token_cost.__name__):
            cost = compute_cost_eur("claude-inconnu-9", 1_000_000, 1_000_000)
            compute_cost_eur("claude-inconnu-9", 1, 1)
        assert cost == compute_cost_eur("claude-sonnet-5", 1_000_000, 1_000_000)
        warnings = [r for r in caplog.records if "claude-inconnu-9" in r.getMessage()]
        assert len(warnings) == 1  # une seule fois par modèle, pas à chaque ligne agrégée

    def test_rate_is_configurable(self, monkeypatch):
        monkeypatch.setattr(settings, "usd_eur_rate", 1.0)
        assert compute_cost_eur("claude-sonnet-4-6", 0, 1_000_000) == 15.0


class TestUsageTotals:
    def test_sums_models_before_rounding(self):
        totals = token_cost.UsageTotals()
        totals.add("claude-sonnet-5", 1_000_000, 0)
        totals.add("claude-haiku-4-5-20251001", 0, 1_000_000)
        assert (totals.input_tokens, totals.output_tokens) == (1_000_000, 1_000_000)
        assert totals.cost_eur == round((2.00 + 5.00) * 0.92, 4)
