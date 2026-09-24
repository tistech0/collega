"""Configuration des logs applicatifs (API et worker).

Sans elle, le logger racine reste à WARNING : tous les `logger.info` sont perdus
et les avertissements sortent sans horodatage.
"""

import logging
import sys

_FORMAT = "%(asctime)s %(levelname)s %(name)s %(message)s"


def configure_logging(level: int = logging.INFO) -> None:
    root = logging.getLogger()
    root.setLevel(level)
    if any(getattr(h, "_collega", False) for h in root.handlers):
        return
    handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(logging.Formatter(_FORMAT))
    handler._collega = True  # type: ignore[attr-defined]
    root.addHandler(handler)
