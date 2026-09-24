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


_UVICORN_ACCESS_FMT = '%s - "%s %s HTTP/%s" %d'


def _access_record(full_path: str) -> logging.LogRecord:
    """Enregistrement façonné comme celui d'uvicorn (`uvicorn.protocols.http`)."""
    return logging.LogRecord(
        "uvicorn.access",
        logging.INFO,
        __file__,
        1,
        _UVICORN_ACCESS_FMT,
        ("203.0.113.7:51234", "GET", full_path, "1.1", 200),
        None,
    )


def _filtered_message(full_path: str) -> str:
    configure_logging()
    record = _access_record(full_path)
    for f in logging.getLogger("uvicorn.access").filters:
        assert f.filter(record) if hasattr(f, "filter") else f(record)
    return record.getMessage()


def test_access_log_sans_query_string() -> None:
    message = _filtered_message("/v1/colleges/search?q=cardiologie%20infantile&limit=5")
    assert message == '203.0.113.7:51234 - "GET /v1/colleges/search HTTP/1.1" 200'
    assert "cardiologie" not in message


def test_access_log_masque_les_uuid() -> None:
    upload_id = "3f2b8c1e-9d4a-4b7e-8f21-0a1b2c3d4e5f"
    message = _filtered_message(f"/v1/colleges/uploads/{upload_id}/parts/3?sig=abc")
    assert message == '203.0.113.7:51234 - "GET /v1/colleges/uploads/<id>/parts/3 HTTP/1.1" 200'
    assert upload_id not in message and upload_id.upper() not in _filtered_message(f"/v1/x/{upload_id.upper()}")


def test_access_log_filtre_installe_une_seule_fois() -> None:
    configure_logging()
    configure_logging()
    filters = logging.getLogger("uvicorn.access").filters
    assert sum(1 for f in filters if getattr(f, "_collega", False)) == 1
