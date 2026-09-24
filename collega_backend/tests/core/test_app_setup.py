from app.main import openapi_url_for
from app.workers.settings import WORKER_SETTINGS


def test_openapi_schema_hidden_in_production() -> None:
    assert openapi_url_for("production") is None
    assert openapi_url_for("development") == "/openapi.json"


def test_worker_retry_budget_is_read_by_arq() -> None:
    # arq lit `max_tries` (défaut 5) ; `max_retries` était ignoré en silence.
    assert WORKER_SETTINGS["max_tries"] == 3
    assert "max_retries" not in WORKER_SETTINGS


def test_worker_health_key_refreshed_often_enough_for_docker_healthcheck() -> None:
    # Le healthcheck Docker (`arq --check`) lit cette clé toutes les 60 s.
    assert WORKER_SETTINGS["health_check_interval"] <= 60


async def test_tester_web_removed(client) -> None:
    # Chantier 5 (R1) : page /tester et routes /v1/tester/* supprimées.
    assert (await client.get("/tester/")).status_code == 404
    assert (await client.get("/v1/tester/colleges")).status_code == 404
