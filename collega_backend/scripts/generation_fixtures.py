"""Items d'un collège relus depuis une fixture de pages (chantier 4, tâche 9), pour les
scripts de mesure (`scripts.measure_prompt_tokens`) et de contrôle de fumée
(`scripts.smoke_generation`). Ni base ni Redis : pages de la fixture + découpage
ACTUEL (`ItemDetector`) — les plages d'items enregistrées dans la fixture sont
celles de l'ancien découpage et ne sont jamais lues.

Fixtures : `college_<n>.json` exportées par `scripts/export_page_fixtures.py`
(clé `pages` : `text`, `confidence`, `tables`). Contenu sous droits : jamais de
texte de page dans les sorties de ces scripts, numéros et compteurs seulement
(les fiches générées du contrôle de fumée exceptées, voir ce script).
"""

from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass
from pathlib import Path

# Réglages factices pour le seul import de la configuration (ces scripts n'ouvrent ni
# base ni Redis). Sans effet si les variables sont déjà définies (conteneur : .env de
# prod). La clé Claude n'a PAS de valeur factice : sans elle, les scripts s'arrêtent.
for _key, _value in {
    # Obligatoire depuis le chantier 2 (hors liste → configuration refusée).
    "ENVIRONMENT": "development",
    "DATABASE_URL": "postgresql+asyncpg://hors-ligne@localhost/hors-ligne",
    "REDIS_URL": "redis://localhost:6379/0",
    "SECRET_KEY": "mesure-generation-hors-ligne-sans-secret",
    "REVENUECAT_WEBHOOK_SECRET": "hors-ligne",
}.items():
    os.environ.setdefault(_key, _value)

from app.services.ocr.item_detector import ItemDetector  # noqa: E402

_FIXTURE_NAME = re.compile(r"^college_(\w+)\.json$")


@dataclass
class FixtureItem:
    college: str
    item_number: int
    title: str
    pages: list[str]  # texte brut de chaque page de l'item (`DetectedItem.pages`)

    @property
    def raw_text(self) -> str:
        """Texte brut de l'item (pages jointes comme `DetectedItem.ocr_text`)."""
        return "\n".join(self.pages)


def fixture_files(directory: Path) -> dict[str, Path]:
    """`college_<n>.json` du dossier, par identifiant de collège (« 3 », « 12 »…), triés."""
    found = {m.group(1): p for p in directory.iterdir() if (m := _FIXTURE_NAME.match(p.name))}
    return dict(
        sorted(found.items(), key=lambda kv: (not kv[0].isdigit(), int(kv[0]) if kv[0].isdigit() else 0, kv[0]))
    )


def load_items(college: str, path: Path) -> list[FixtureItem]:
    """Items du collège selon le découpage actuel, avec le texte brut de leurs pages
    (comme `app.workers.ocr_worker.with_pages`)."""
    pages = json.loads(path.read_text())["pages"]
    texts = [p["text"] for p in pages]
    result = ItemDetector().detect_items(texts, [p["confidence"] for p in pages], [p["tables"] for p in pages])
    return [
        FixtureItem(
            college=college, item_number=d.item_number, title=d.chapter_title, pages=[texts[i] for i in d.pages]
        )
        for d in result.items
    ]
