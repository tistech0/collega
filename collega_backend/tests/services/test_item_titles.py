"""Tests du filtre de titres d'items (story 8.0) — fonctions pures."""

import pytest

from app.services.ocr.item_titles import clean_title, is_valid_title


class TestCleanTitle:
    def test_strips_trailing_period(self):
        assert clean_title("Addiction au tabac.") == "Addiction au tabac"

    def test_collapses_whitespace_and_newlines(self):
        assert (
            clean_title("Infections broncho-pulmonaires\n  communautaires de l’adulte.")
            == "Infections broncho-pulmonaires communautaires de l’adulte"
        )

    def test_strips_leading_separators(self):
        assert clean_title(" – Tumeurs du testicule") == "Tumeurs du testicule"
        assert clean_title(": Tumeurs du rein") == "Tumeurs du rein"

    def test_keeps_original_case(self):
        assert clean_title("Tumeurs du poumon, primitives et secondaires") == (
            "Tumeurs du poumon, primitives et secondaires"
        )

    def test_truncates_to_200_at_word_boundary(self):
        long = "Prise en charge " + "et accompagnement " * 20
        out = clean_title(long)
        assert len(out) <= 200
        assert not out.endswith(" ")
        assert long.startswith(out)
        assert long[len(out)] == " "


class TestIsValidTitle:
    @pytest.mark.parametrize(
        "title",
        [
            "Addiction au tabac",
            "Troubles du sommeil de l’enfant et de l’adulte",
            "Tumeurs du poumon, primitives et secondaires",
            "Pneumothorax",
            "Épidémiologie, facteurs de risque, prévention et dépistage des cancers",
            "Cancer : cancérogenèse, oncogénétique",
            "Tumeurs de l'œsophage",
        ],
    )
    def test_accepts_real_titles(self, title):
        assert is_valid_title(title)

    @pytest.mark.parametrize(
        "title",
        [
            # Les 5 titres faux trouvés en prod (extraits par l'ancien _CHAPTER_PATTERN)
            "d'un malade atteint de cancer",
            "à l'hyperœstrogénie induite : en préménopause, elle favorise une exposition",
            "Pr Michel Ducreux1, Pr Serge Evrard2, Pr Françoise Mornex3, Pr Michel Rivoire4",
            "Les objectifs de rang B apparaissent en italique dans le texte",
            "de ces objectifs",
        ],
    )
    def test_rejects_prod_garbage(self, title):
        assert not is_valid_title(title)

    @pytest.mark.parametrize(
        "title",
        [
            "",
            "Abc",
            "Titre",  # un seul mot, < 6 lettres
            "... .. . ...",
            "12 345 678",
            "Tumeurs du foie ...................... 229",
            "• Les recommandations sont de ne pas dépasser dix verres",
            "Dr Boris Duchemann, Dr Eurydice Angeli",
            "X" * 201,
        ],
    )
    def test_rejects_noise(self, title):
        assert not is_valid_title(title)


# ── Référentiel partagé (SQL réel sur SQLite) ────────────────────────────────

import uuid  # noqa: E402

from sqlalchemy import select  # noqa: E402

from app.models.item import Item  # noqa: E402
from app.models.item_title import ItemTitle  # noqa: E402
from app.services.ocr.item_titles import lookup_title, record_title  # noqa: E402


def _item(number: int, title: str | None) -> Item:
    return Item(
        college_id=uuid.uuid4(),
        item_number=number,
        rang="A",
        chapter_title=title,
        ocr_confidence_score=0.9,
    )


class TestReferential:
    async def test_record_creates_entry(self, sqlite_session):
        await record_title(sqlite_session, 310, "Tumeurs du testicule")
        rows = (await sqlite_session.execute(select(ItemTitle))).scalars().all()
        assert [(r.item_number, r.label, r.source, r.occurrences) for r in rows] == [
            (310, "Tumeurs du testicule", "extracted", 1)
        ]

    async def test_record_same_label_increments(self, sqlite_session):
        await record_title(sqlite_session, 310, "Tumeurs du testicule")
        await record_title(sqlite_session, 310, "Tumeurs du testicule")
        row = (await sqlite_session.execute(select(ItemTitle))).scalar_one()
        assert row.occurrences == 2

    async def test_record_rejects_invalid(self, sqlite_session):
        recorded = await record_title(sqlite_session, 295, "d'un malade atteint de cancer")
        assert recorded is False
        assert (await sqlite_session.execute(select(ItemTitle))).first() is None

    async def test_lookup_most_frequent_wins(self, sqlite_session):
        await record_title(sqlite_session, 309, "Tumeurs du poumon")
        await record_title(sqlite_session, 309, "Tumeurs du poumon, primitives et secondaires")
        await record_title(sqlite_session, 309, "Tumeurs du poumon, primitives et secondaires")
        assert await lookup_title(sqlite_session, 309) == ("Tumeurs du poumon, primitives et secondaires")

    async def test_lookup_tie_oldest_wins(self, sqlite_session):
        await record_title(sqlite_session, 309, "Tumeurs du poumon")
        await record_title(sqlite_session, 309, "Cancers bronchiques")
        assert await lookup_title(sqlite_session, 309) == "Tumeurs du poumon"

    async def test_lookup_official_wins(self, sqlite_session):
        await record_title(sqlite_session, 309, "Tumeurs du poumon")
        await record_title(sqlite_session, 309, "Tumeurs du poumon")
        sqlite_session.add(
            ItemTitle(item_number=309, label="Tumeurs du poumon, primitives et secondaires", source="official")
        )
        await sqlite_session.flush()
        assert await lookup_title(sqlite_session, 309) == ("Tumeurs du poumon, primitives et secondaires")

    async def test_lookup_unknown_returns_none(self, sqlite_session):
        assert await lookup_title(sqlite_session, 1) is None

    async def test_record_completes_untitled_items(self, sqlite_session):
        """AC7 — un titre valide complète rétroactivement les items vides du même numéro."""
        empty, blank, titled, other = (
            _item(310, None),
            _item(310, ""),
            _item(310, "Tumeurs du testicule (CNEC)"),
            _item(311, None),
        )
        sqlite_session.add_all([empty, blank, titled, other])
        await sqlite_session.flush()

        await record_title(sqlite_session, 310, "Tumeurs du testicule")

        for item in (empty, blank, titled, other):
            await sqlite_session.refresh(item)
        assert empty.chapter_title == "Tumeurs du testicule"
        assert blank.chapter_title == "Tumeurs du testicule"
        assert titled.chapter_title == "Tumeurs du testicule (CNEC)"
        assert other.chapter_title is None


class TestCleanTitleProdCases:
    def test_all_caps_to_sentence_case(self):
        assert clean_title("BRONCHOPNEUMOPATHIE CHRONIQUE") == "Bronchopneumopathie chronique"

    def test_mixed_case_untouched(self):
        assert clean_title("Hypersensibilités et Allergies Respiratoires") == (
            "Hypersensibilités et Allergies Respiratoires"
        )

    def test_truncation_drops_dangling_short_words(self):
        raw = (
            "Prise en charge et accompagnement d'un malade atteint de cancer à tous les stades "
            "de la maladie dont le stade de soins palliatifs en abordant les problématiques "
            "techniques, relationnelles, sociales et éthiques"
        )
        out = clean_title(raw)
        assert len(out) <= 200
        assert out.endswith("sociales")

    def test_rejects_title_without_real_word(self):
        assert not is_valid_title("Œ Q A")


class TestOfficialTitle:
    async def test_official_title_fills_and_wins(self, sqlite_session):
        from app.services.ocr.item_titles import record_official_title

        item = _item(338, None)
        sqlite_session.add(item)
        await record_title(sqlite_session, 338, "Deme de uincke et naphylaxie")
        await record_official_title(sqlite_session, 338, "Œdème de Quincke et anaphylaxie")
        await sqlite_session.refresh(item)
        assert await lookup_title(sqlite_session, 338) == "Œdème de Quincke et anaphylaxie"

    async def test_official_title_is_idempotent(self, sqlite_session):
        from app.services.ocr.item_titles import record_official_title

        await record_official_title(sqlite_session, 338, "Œdème de Quincke et anaphylaxie")
        await record_official_title(sqlite_session, 338, "Œdème de Quincke et anaphylaxie")
        rows = (await sqlite_session.execute(select(ItemTitle))).scalars().all()
        assert [(r.label, r.source) for r in rows] == [("Œdème de Quincke et anaphylaxie", "official")]

    async def test_official_title_corrects_item_filled_by_extraction(self, sqlite_session):
        """Un libellé officiel remplace le titre qu'un item tenait du référentiel extrait."""
        from app.services.ocr.item_titles import record_official_title

        item = _item(338, None)
        sqlite_session.add(item)
        await record_title(sqlite_session, 338, "Deme de uincke et naphylaxie")
        await sqlite_session.refresh(item)
        assert item.chapter_title == "Deme de uincke et naphylaxie"
        await record_official_title(sqlite_session, 338, "Œdème de Quincke et anaphylaxie")
        await sqlite_session.refresh(item)
        assert item.chapter_title == "Œdème de Quincke et anaphylaxie"


class TestReviewFindingsTitles:
    @pytest.mark.parametrize(
        "title",
        [
            "Rang Rubrique Intitulé Descriptif",
            "Introduction",
            "Épidémiologie",
            "Généralités",
            "Physiopathologie",
            "Diagnostic",
            "Sommaire",
        ],
    )
    def test_rejects_table_header_and_section_headings(self, title):
        assert not is_valid_title(title)

    async def test_ensure_title_does_not_increment(self, sqlite_session):
        from app.services.ocr.item_titles import ensure_title

        await record_title(sqlite_session, 310, "Tumeurs du testicule")
        await ensure_title(sqlite_session, 310, "Tumeurs du testicule")
        await ensure_title(sqlite_session, 310, "Tumeurs du testicule")
        row = (await sqlite_session.execute(select(ItemTitle))).scalar_one()
        assert row.occurrences == 1

    async def test_ensure_title_inserts_and_fills(self, sqlite_session):
        from app.services.ocr.item_titles import ensure_title

        item = _item(310, None)
        sqlite_session.add(item)
        await ensure_title(sqlite_session, 310, "Tumeurs du testicule")
        await sqlite_session.refresh(item)
        assert item.chapter_title == "Tumeurs du testicule"

    async def test_failure_after_insert_leaves_session_usable(self, sqlite_session, monkeypatch):
        """Une erreur dans la complétion ne doit pas empoisonner la transaction de l'import."""
        from app.services.ocr import item_titles

        async def boom(db, number):
            await db.execute(select(ItemTitle).where(ItemTitle.id == "x" * 5000))  # requête valide
            raise RuntimeError("échec complétion")

        monkeypatch.setattr(item_titles, "backfill_untitled_items", boom)
        with pytest.raises(RuntimeError):
            await record_title(sqlite_session, 310, "Tumeurs du testicule")
        sqlite_session.add(_item(311, None))
        await sqlite_session.flush()  # la session reste utilisable
        assert (await sqlite_session.execute(select(ItemTitle))).first() is None
