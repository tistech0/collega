"""Configuration des logs applicatifs (API et worker).

Sans elle, le logger racine reste à WARNING : tous les `logger.info` sont perdus
et les avertissements sortent sans horodatage.

Le journal d'accès d'uvicorn écrit la ligne de requête complète : la query string
(termes de recherche `q=`) est retirée et tout UUID du chemin (collège, upload…)
est remplacé par `<id>` (chantier 2, aucun terme cherché ni identifiant d'upload
dans les journaux).
"""

import logging
import re
import sys

_FORMAT = "%(asctime)s %(levelname)s %(name)s %(message)s"
_UUID_RE = re.compile(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")


def _mask_path(full_path: str) -> str:
    path = full_path.split("?", 1)[0]
    return _UUID_RE.sub("<id>", path)


class AccessPathFilter(logging.Filter):
    """Réécrit le chemin des lignes `uvicorn.access` (args : client, méthode, chemin,
    version HTTP, statut) : sans query string, UUID masqués. Ne supprime aucune ligne."""

    _collega = True

    def filter(self, record: logging.LogRecord) -> bool:
        args = record.args
        if isinstance(args, tuple) and len(args) == 5 and isinstance(args[2], str):
            record.args = (args[0], args[1], _mask_path(args[2]), args[3], args[4])
        return True


def _install_access_filter() -> None:
    access = logging.getLogger("uvicorn.access")
    if not any(getattr(f, "_collega", False) for f in access.filters):
        access.addFilter(AccessPathFilter())


def configure_logging(level: int = logging.INFO) -> None:
    _install_access_filter()
    root = logging.getLogger()
    root.setLevel(level)
    if any(getattr(h, "_collega", False) for h in root.handlers):
        return
    handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(logging.Formatter(_FORMAT))
    handler._collega = True  # type: ignore[attr-defined]
    root.addHandler(handler)
