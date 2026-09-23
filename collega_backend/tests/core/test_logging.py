import logging

from app.core.logging import configure_logging


def test_configure_logging_emits_info_with_timestamp(capsys) -> None:
    root = logging.getLogger()
    saved = (root.level, root.handlers[:])
    try:
        root.handlers = []
        configure_logging()
        configure_logging()  # idempotent : pas de double handler

        logging.getLogger("app.test").info("bonjour")

        err = capsys.readouterr().err.strip().splitlines()
        assert len(err) == 1
        assert err[0].endswith("INFO app.test bonjour")
        assert err[0][:4].isdigit()  # horodatage en tête (AAAA-…)
    finally:
        root.setLevel(saved[0])
        root.handlers = saved[1]
