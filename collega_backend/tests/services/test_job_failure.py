import pytest
from sqlalchemy import func, select

from app.core.config import settings
from app.models.college import College
from app.models.content import JobItem, JobPage
from app.models.generation_job import GenerationJob
from app.models.generation_job_event import GenerationJobEvent
from app.services.jobs.job_failure import fail_job
from tests.factories import Seed, make_college, make_draft, make_job, make_job_page, make_user, write_pdf

pytestmark = pytest.mark.pg


async def _seed(pg_factory, tmp_path, monkeypatch, college_status: str) -> Seed:
    monkeypatch.setattr(settings, "pdf_storage_path", str(tmp_path))
    async with pg_factory() as db:
        user = await make_user(db, monthly_reloads=1)
        college = await make_college(db, user, status=college_status, reload_count=1)
        job = await make_job(db, college, status="ocr_complete")
        await make_job_page(db, job, 0, "page")
        await make_draft(db, job, 304, "texte")
        await db.commit()
    return Seed(user, college, job, write_pdf(tmp_path, college, job))


@pytest.fixture
async def seed_reimport(pg_factory, tmp_path, monkeypatch):
    return await _seed(pg_factory, tmp_path, monkeypatch, "generation_complete")


@pytest.fixture
async def seed_first_import(pg_factory, tmp_path, monkeypatch):
    return await _seed(pg_factory, tmp_path, monkeypatch, "ocr_complete")


async def test_reimport_failure_keeps_college_content(pg_factory, seed_reimport):
    assert await fail_job(pg_factory, seed_reimport.job.id, "Claude indisponible", notify=False)
    async with pg_factory() as s:
        job = await s.get(GenerationJob, seed_reimport.job.id)
        college = await s.get(College, seed_reimport.college.id)
        assert (job.status, job.error_message) == ("failed", "Claude indisponible")
        assert college.status == "generation_complete"
        assert (await s.execute(select(func.count()).select_from(JobPage))).scalar_one() == 0
        assert (await s.execute(select(func.count()).select_from(JobItem))).scalar_one() == 0
        events = (await s.execute(select(GenerationJobEvent.event_type))).scalars().all()
        assert events == ["failed"]
    assert not seed_reimport.pdf_path.exists()


async def test_first_import_failure_marks_college_failed(pg_factory, seed_first_import):
    await fail_job(pg_factory, seed_first_import.job.id, "boom", notify=False)
    async with pg_factory() as s:
        assert (await s.get(College, seed_first_import.college.id)).status == "failed"


async def test_already_failed_job_is_left_alone(pg_factory, seed_reimport):
    await fail_job(pg_factory, seed_reimport.job.id, "premier", notify=False)
    assert await fail_job(pg_factory, seed_reimport.job.id, "second", notify=False) is False
    async with pg_factory() as s:
        assert (await s.get(GenerationJob, seed_reimport.job.id)).error_message == "premier"


async def test_missing_job_returns_false(pg_factory):
    import uuid

    assert await fail_job(pg_factory, uuid.uuid4(), "x", notify=False) is False


async def test_custom_event_type(pg_factory, seed_reimport):
    await fail_job(pg_factory, seed_reimport.job.id, "bloqué", event="stale", notify=False)
    async with pg_factory() as s:
        assert (await s.execute(select(GenerationJobEvent.event_type))).scalars().all() == ["stale"]


async def test_failure_notifies_owner(pg_factory, seed_reimport, monkeypatch):
    sent = []

    class Spy:
        async def send_import_failed(self, token, ref_id, reimport):
            sent.append((token, ref_id, reimport))

    monkeypatch.setattr("app.services.jobs.job_failure.get_notification_service", lambda: Spy())
    await fail_job(pg_factory, seed_reimport.job.id, "boom")
    assert sent == [("tok", 34, True)]


async def test_notification_error_never_breaks_failure(pg_factory, seed_reimport, monkeypatch):
    class Broken:
        async def send_import_failed(self, *a):
            raise RuntimeError("APNs KO")

    monkeypatch.setattr("app.services.jobs.job_failure.get_notification_service", lambda: Broken())
    assert await fail_job(pg_factory, seed_reimport.job.id, "boom") is True


async def test_failed_reimport_gives_back_quota(pg_factory, seed_reimport):
    from app.models.user import User

    await fail_job(pg_factory, seed_reimport.job.id, "Claude indisponible", notify=False)
    async with pg_factory() as s:
        assert (await s.get(College, seed_reimport.college.id)).reload_count == 0
        assert (await s.get(User, seed_reimport.user.id)).monthly_reloads == 0


async def test_failed_first_import_consumes_no_quota_change(pg_factory, seed_first_import):
    from app.models.user import User

    await fail_job(pg_factory, seed_first_import.job.id, "boom", notify=False)
    async with pg_factory() as s:
        # Un premier import ne consomme pas de quota au router : rien à rendre.
        assert (await s.get(College, seed_first_import.college.id)).reload_count == 1
        assert (await s.get(User, seed_first_import.user.id)).monthly_reloads == 1
