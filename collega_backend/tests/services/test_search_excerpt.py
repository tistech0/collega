"""Extrait de recherche = la phrase entière avec le terme surligné (story 8.10)."""
from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock

from app.services.search.full_text_search import build_excerpt, search_flash_cards


def test_phrase_entiere_contenant_le_terme():
    text = "Le BNP est un peptide natriurétique. Il augmente dans l'insuffisance cardiaque. Autre phrase."
    headline = "Il <mark>augmente</mark> dans l'insuffisance"
    assert build_excerpt(text, headline) == "Il <mark>augmente</mark> dans l'insuffisance cardiaque."


def test_casse_d_origine_conservee_et_toutes_les_occurrences():
    text = "Dosage du bnp : le BNP s'élève. Fin."
    headline = "Dosage du <mark>bnp</mark>"
    assert build_excerpt(text, headline) == "Dosage du <mark>bnp</mark> : le <mark>BNP</mark> s'élève."


def test_plusieurs_termes_la_premiere_phrase_qui_en_contient_un():
    text = "Rien ici. Traitement par amoxicilline à forte dose. Surveillance."
    headline = "par <mark>amoxicilline</mark> à forte <mark>dose</mark>"
    assert build_excerpt(text, headline) == "Traitement par <mark>amoxicilline</mark> à forte <mark>dose</mark>."


def test_mot_entier_seulement():
    text = "Ictère cutanéo-muqueux et IC décompensée."
    headline = "et <mark>IC</mark> décompensée"
    assert build_excerpt(text, headline) == "Ictère cutanéo-muqueux et <mark>IC</mark> décompensée."


def test_phrase_trop_longue_fenetre_autour_du_terme():
    before = " ".join(["mot"] * 60)
    after = " ".join(["suite"] * 60)
    text = f"{before} BNP {after}."
    out = build_excerpt(text, "<mark>BNP</mark>", max_chars=120)
    assert "<mark>BNP</mark>" in out
    assert out.startswith("…") and out.endswith("…")
    assert len(out.replace("<mark>", "").replace("</mark>", "")) <= 122


def test_puces_et_retours_a_la_ligne_separent_les_phrases():
    text = "Signes :\n- dyspnée d'effort\n- œdèmes des membres inférieurs"
    headline = "<mark>œdèmes</mark> des membres"
    assert build_excerpt(text, headline) == "<mark>œdèmes</mark> des membres inférieurs"


def test_sans_surlignage_le_headline_est_rendu_tel_quel():
    assert build_excerpt("Texte.", "Texte.") == "Texte."


def test_terme_absent_du_texte_repli_sur_le_headline():
    assert build_excerpt("Autre chose.", "x <mark>BNP</mark> y") == "x <mark>BNP</mark> y"


async def test_service_remplace_l_extrait_et_retire_le_texte_brut():
    row = {
        "item_id": str(uuid.uuid4()), "item_number": 232, "rang": "A", "chapter_title": "IC",
        "college_id": str(uuid.uuid4()), "college_ref_id": 1,
        "excerpt": "le <mark>BNP</mark> s'élève", "rank": 0.8,
        "recto": "Quel marqueur ?", "verso": "Dosage : le BNP s'élève. Fin.",
    }
    result = MagicMock()
    result.mappings.return_value.all.return_value = [row]
    db = types.SimpleNamespace(execute=AsyncMock(return_value=result))
    out = await search_flash_cards(db, uuid.uuid4(), "BNP")
    assert out[0]["excerpt"] == "Dosage : le <mark>BNP</mark> s'élève."
    assert "recto" not in out[0] and "verso" not in out[0]
