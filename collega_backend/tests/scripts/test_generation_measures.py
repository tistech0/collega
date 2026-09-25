"""Chantier 4, tâche 9 — scripts de mesure des tokens et de contrôle de fumée, de bout en
bout sur une fixture synthétique et un faux client Anthropic (aucun appel réel)."""

import json
from types import SimpleNamespace

import pytest

from app.services.generation.claude_client import GENERATION_MODEL, GENERATION_SYSTEM_PROMPT, ClaudeClient
from scripts import measure_prompt_tokens, smoke_generation
from scripts.generation_fixtures import fixture_files, load_items
from scripts.smoke_generation import check_numbers, parse_items

WATERMARK = "Pour avoir plus d'exclusivités rejoindre nous sur www.amis-med.com"
BODY = "La dose est de 5 mg/kg pendant 0,5 jour chez l'adulte, cours assez long pour une vraie page."
PAGES = [
    "SOMMAIRE\nItem 290 ....... 1\nItem 291 ....... 3\n",
    f"Item 290\nOBJECTIFS: N° 290. Épidémiologie\nRang Rubrique Intitulé\nA Définition x\n{BODY}\n{WATERMARK}\n12",
    f"Item 290\n{BODY}\n{WATERMARK}\n13\n{BODY}",
    f"Item 291\nOBJECTIFS: N° 291. Cancérogenèse\n{BODY}\n{WATERMARK}\n14",
    "",
]


def _write_fixtures(directory, colleges=("3", "12")):
    for college in colleges:
        pages = [
            {"page_number": i, "text": t, "confidence": 0.9, "tables": [], "method": "text"}
            for i, t in enumerate(PAGES)
        ]
        # Plages de l'ancien découpage stockées dans la fixture : jamais lues.
        (directory / f"college_{college}.json").write_text(json.dumps({"items": [{"bogus": True}], "pages": pages}))
    (directory / "autre.json").write_text("{}")


class FakeMessages:
    def __init__(self, cards=None, stop_reason="end_turn"):
        self.count_calls: list[dict] = []
        self.create_calls: list[dict] = []
        self.cards = cards if cards is not None else []
        self.stop_reason = stop_reason

    async def count_tokens(self, **kwargs):
        self.count_calls.append(kwargs)
        text = kwargs["system"] + "".join(m["content"] for m in kwargs["messages"])
        return SimpleNamespace(input_tokens=len(text) // 4)

    async def create(self, **kwargs):
        self.create_calls.append(kwargs)
        payload = {"flashcards": self.cards, "insufficient_text": False}
        return SimpleNamespace(
            content=[SimpleNamespace(type="thinking"), SimpleNamespace(type="text", text=json.dumps(payload))],
            usage=SimpleNamespace(input_tokens=1000, output_tokens=500),
            stop_reason=self.stop_reason,
        )


def test_load_items_uses_current_segmentation(tmp_path):
    _write_fixtures(tmp_path)
    assert list(fixture_files(tmp_path)) == ["3", "12"]
    items = load_items("3", tmp_path / "college_3.json")
    assert [(it.item_number, len(it.pages)) for it in items] == [(290, 2), (291, 1)]
    assert items[0].pages == PAGES[1:3]


def test_measure_counts_raw_and_cleaned_per_college(tmp_path, capsys):
    _write_fixtures(tmp_path)
    fake = SimpleNamespace(messages=FakeMessages())
    out = tmp_path / "measure.json"
    assert measure_prompt_tokens.main(["--fixtures", str(tmp_path), "--out", str(out)], client=fake) == 0

    report = json.loads(out.read_text())
    assert report["model"] == GENERATION_MODEL
    # 2 items × 2 collèges × (brut + allégé)
    assert len(fake.messages.count_calls) == 8
    call = fake.messages.count_calls[0]
    assert call["model"] == "claude-sonnet-5" and call["system"] == GENERATION_SYSTEM_PROMPT
    assert call["messages"][0]["content"].startswith("Item 290 — ")
    for college in ("3", "12"):
        t = report["colleges"][college]
        assert t["items"] == 2
        assert t["tokens_cleaned"] < t["tokens_raw"] and t["chars_cleaned"] < t["chars_raw"]
        assert 0 < t["tokens_reduction_pct"] < 100
        assert [m["item_number"] for m in t["per_item"]] == [290, 291]
    assert report["total"]["items"] == 4
    assert report["total"]["tokens_raw"] == 2 * report["colleges"]["3"]["tokens_raw"]

    printed = capsys.readouterr().out
    assert "| collège 3 | 2 |" in printed and "**total**" in printed
    # Aucun texte de page dans la sortie ni dans le JSON.
    for text in (BODY, WATERMARK, "Épidémiologie"):
        assert text not in printed and text not in out.read_text()


def test_measure_without_fixtures_fails(tmp_path):
    assert (
        measure_prompt_tokens.main(["--fixtures", str(tmp_path), "--out", str(tmp_path / "o.json")], client=object())
        == 2
    )


def test_check_numbers_reports_numbers_missing_from_source():
    cards = [
        SimpleNamespace(verso="5 mg/kg pendant 0.5 jour"),
        SimpleNamespace(verso="Seuil de 42 mmHg, puis 7,5 et 15"),
    ]
    result = check_numbers(cards, "dose 5 mg/kg, 0,5 jour, 150 patients")
    assert result["unmatched_numbers"] == 3  # 42, 7,5, 15 (15 ≠ 150)
    assert len(result["unmatched_examples"]) == 3
    assert all(len(f) <= 60 for f in result["unmatched_examples"])
    assert "42" in result["unmatched_examples"][0]


def test_parse_items():
    assert parse_items("3:305, 12:216") == {"3": 305, "12": 216}
    with pytest.raises(ValueError):
        parse_items("3-305")


def _smoke_client(fake: FakeMessages) -> ClaudeClient:
    client = ClaudeClient()
    client._client = SimpleNamespace(messages=fake)  # type: ignore[assignment]
    return client


CARDS = [
    {"type": "classique", "rang": "A", "recto": "Dose ?", "verso": "5 mg/kg pendant 0,5 jour"},
    {"type": "definition", "rang": "A", "recto": "Définition ?", "verso": "Sans nombre"},
    {"type": "cas_clinique", "rang": "B", "recto": "Homme de 60 ans…", "verso": "Seuil 42 | autre"},
    {"type": "classique", "rang": "B", "recto": "R" * 300, "verso": "V"},
]


def test_smoke_generation_end_to_end(tmp_path, capsys):
    _write_fixtures(tmp_path)
    fake = FakeMessages(cards=CARDS)
    out = tmp_path / "smoke.json"
    code = smoke_generation.main(["--fixtures", str(tmp_path), "--out", str(out)], client=_smoke_client(fake))
    assert code == 0

    # Un item par collège, effort low puis medium, via le vrai generate_cards.
    assert [c["output_config"]["effort"] for c in fake.create_calls] == ["low", "medium", "low", "medium"]
    assert all(c["model"] == "claude-sonnet-5" for c in fake.create_calls)
    report = json.loads(out.read_text())
    # Collège 3 : item médian (291 plus court que 290 → médian = index 1 = 290) ; collège 12 : le plus long (290).
    assert [(i["college"], i["item_number"]) for i in report["items"]] == [("3", 290), ("12", 290)]
    run = report["items"][0]["runs"][0]
    assert run["effort"] == "low" and run["cards"] == 4
    assert run["by_rang"] == {"A": 2, "B": 2}
    assert run["by_type"] == {"classique": 2, "definition": 1, "cas_clinique": 1}
    assert (run["input_tokens"], run["output_tokens"]) == (1000, 500)
    assert run["cost_usd"] == pytest.approx(0.007)
    assert run["cost_eur"] > 0
    assert run["insufficient_text"] is False and run["stop_reason"] == "end_turn"
    assert run["unmatched_numbers"] == 1 and "42" in run["unmatched_examples"][0]
    assert report["total_cost_eur"]["low"] == pytest.approx(2 * run["cost_eur"])

    printed = capsys.readouterr().out
    assert "| 3 | 290 | 2 |" in printed and "| low | 4 | A 2 B 2 |" in printed
    # Au plus 3 exemples par item, tronqués ; jamais de texte source.
    assert printed.count("| classique | A | Dose ? |") == 2
    assert "R" * 100 not in printed  # 4e fiche non montrée
    assert "Seuil 42 / autre" in printed and "Seuil 42 | autre" not in printed
    assert BODY not in printed and WATERMARK not in printed


def test_smoke_generation_items_override_and_errors(tmp_path, capsys):
    _write_fixtures(tmp_path)
    fake = FakeMessages(cards=CARDS[:1])
    out = tmp_path / "smoke.json"
    args = ["--fixtures", str(tmp_path), "--out", str(out)]
    assert smoke_generation.main([*args, "--items", "12:291"], client=_smoke_client(fake)) == 0
    report = json.loads(out.read_text())
    assert [(i["college"], i["item_number"]) for i in report["items"]] == [("12", 291)]
    assert report["items"][0]["runs"][1]["unmatched_numbers"] == 0

    assert smoke_generation.main([*args, "--items", "12:999"], client=_smoke_client(fake)) == 2
    assert smoke_generation.main([*args, "--items", "34:290"], client=_smoke_client(fake)) == 2
    assert "Erreur" in capsys.readouterr().err


def test_smoke_generation_records_api_error_and_truncates_examples(tmp_path, capsys):
    import anthropic
    import httpx

    class FlakyMessages(FakeMessages):
        async def create(self, **kwargs):
            if kwargs["output_config"]["effort"] == "low":
                raise anthropic.APIConnectionError(request=httpx.Request("POST", "https://api.invalid"))
            return await super().create(**kwargs)

    _write_fixtures(tmp_path, colleges=("34",))
    out = tmp_path / "smoke.json"
    fake = FlakyMessages(cards=[{"type": "classique", "rang": "A", "recto": "Q" * 300, "verso": "V"}])
    assert smoke_generation.main(["--fixtures", str(tmp_path), "--out", str(out)], client=_smoke_client(fake)) == 0
    runs = json.loads(out.read_text())["items"][0]["runs"]
    assert runs[0] == {"effort": "low", "error": "APIConnectionError", "duration_s": runs[0]["duration_s"]}
    assert runs[1]["cards"] == 1
    printed = capsys.readouterr().out
    assert "erreur APIConnectionError" in printed
    assert "Q" * 119 + "…" in printed and "Q" * 120 not in printed
