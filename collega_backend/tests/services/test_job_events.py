"""Tests record_job_event — écriture défensive de la timeline (Story 7.7 AC #1)."""

from __future__ import annotations

import uuid
from unittest.mock import MagicMock

from app.models.generation_job_event import GenerationJobEvent
from app.services.jobs.job_events import record_job_event


class TestRecordJobEvent:
    async def test_adds_event_to_session(self):
        db = MagicMock()
        added = []
        db.add = MagicMock(side_effect=lambda o: added.append(o))

        job_id = uuid.uuid4()
        await record_job_event(db, job_id, "ocr_progress", message="m", page=3, total=10)

        assert len(added) == 1
        ev = added[0]
        assert isinstance(ev, GenerationJobEvent)
        assert ev.generation_job_id == job_id
        assert ev.event_type == "ocr_progress"
        assert ev.message == "m"
        assert ev.page == 3
        assert ev.total == 10
        # Pas de commit dans le helper : le flux appelant porte le commit
        db.commit.assert_not_called()

    async def test_does_not_raise_when_add_fails(self):
        """Un échec d'écriture d'event ne doit jamais casser le pipeline."""
        db = MagicMock()
        db.add = MagicMock(side_effect=RuntimeError("session boom"))

        # Ne doit PAS propager l'exception
        await record_job_event(db, uuid.uuid4(), "failed", message="x")
