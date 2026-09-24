"""Story 8.0 — rapprochement titres extraits du PDF ↔ items en base (fonction pure)."""

import uuid

from scripts.backfill_item_titles import plan_updates


def test_fills_only_untitled_items():
    a, b, c = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    items = [(a, 290, None), (b, 291, ""), (c, 292, "Diagnostic des cancers")]
    extracted = {290: "Épidémiologie des cancers", 291: "Cancer : cancérogenèse", 292: "Autre titre"}
    assert plan_updates(items, extracted) == [(a, "Épidémiologie des cancers"), (b, "Cancer : cancérogenèse")]


def test_missing_extraction_is_skipped():
    a = uuid.uuid4()
    assert plan_updates([(a, 313, None)], {}) == []


def test_parse_overrides():
    from scripts.backfill_item_titles import parse_overrides

    assert parse_overrides(["338=Œdème de Quincke et anaphylaxie"]) == {338: "Œdème de Quincke et anaphylaxie"}


def test_parse_overrides_rejects_malformed():
    import pytest

    from scripts.backfill_item_titles import parse_overrides

    for bad in ["338", "abc=Titre", "338="]:
        with pytest.raises(ValueError):
            parse_overrides([bad])
