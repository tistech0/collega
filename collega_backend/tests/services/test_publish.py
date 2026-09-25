"""Bascule d'un import (chantier 1) sur Postgres réel."""

import json
import uuid

import pytest
from sqlalchemy import func, select

from app.core.config import settings
from app.models.content import CollegePage, JobItem, JobPage
from app.models.flash_card import FlashCard
from app.models.item import Item
from app.services.generation.publish import publish_job, stale_pdfs
from tests.factories import cards, make_card, make_college, make_draft, make_item, make_job, make_job_page, make_user

pytestmark = pytest.mark.pg


async def _setup(db, *, status="generation_complete", reload_count=0, monthly=0):
    user = await make_user(db, monthly_reloads=monthly)
    college = await make_college(db, user, status=status, reload_count=reload_count)
    job = await make_job(db, college, status="ocr_complete")
    return user, college, job


async def _cards_by_item(db, college_id):
    rows = (await db.execute(select(FlashCard).where(FlashCard.college_id == college_id))).scalars().all()
    out: dict[uuid.UUID, list[FlashCard]] = {}
    for c in rows:
        out.setdefault(c.item_id, []).append(c)
    return out


async def test_first_import_creates_items_and_cards(pg_session):
    _, college, job = await _setup(pg_session, status="ocr_complete")
    await make_draft(pg_session, job, 304, "texte 304", cards("Q1", "Q2"))
    await make_draft(pg_session, job, 305, "texte 305", cards("Q3"))
    await pg_session.commit()

    summary = await publish_job(pg_session, job.id, claude_calls=2)
    await pg_session.commit()

    assert (summary.added, summary.changed, summary.removed, summary.unchanged, summary.cards) == (2, 0, 0, 0, 3)
    items = (await pg_session.execute(select(Item).order_by(Item.item_number))).scalars().all()
    assert [i.item_number for i in items] == [304, 305]
    by_item = await _cards_by_item(pg_session, college.id)
    assert sorted(c.recto for c in by_item[items[0].id]) == ["Q1", "Q2"]
    assert all(c.generation_id is not None and c.user_id == college.user_id for cs in by_item.values() for c in cs)
    await pg_session.refresh(college)
    await pg_session.refresh(job)
    assert (college.status, job.status, job.card_count) == ("generation_complete", "generation_complete", 3)


async def test_unchanged_item_keeps_cards_ids_feedback_and_user_changes(pg_session):
    _, college, job = await _setup(pg_session)
    item = await make_item(pg_session, college, 304, text="même texte")
    liked = await make_card(pg_session, item, recto="ancienne Q", user_feedback="positive")
    regenerated = await make_card(pg_session, item, recto="régénérée par elle")
    await make_draft(pg_session, job, 304, "même texte", cards("NOUVELLE"))
    await pg_session.commit()

    summary = await publish_job(pg_session, job.id, claude_calls=0)
    await pg_session.commit()

    assert (summary.unchanged, summary.changed) == (1, 0)
    rows = (await pg_session.execute(select(FlashCard))).scalars().all()
    assert {c.id for c in rows} == {liked.id, regenerated.id}
    assert {c.recto for c in rows} == {"ancienne Q", "régénérée par elle"}
    assert (await pg_session.get(FlashCard, liked.id)).user_feedback == "positive"


async def test_unchanged_item_metadata_is_refreshed(pg_session):
    _, college, job = await _setup(pg_session)
    item = await make_item(pg_session, college, 304, text="même texte")
    draft = await make_draft(pg_session, job, 304, "même texte", None)
    draft.start_page, draft.end_page, draft.chapter_title = 40, 45, "Nouveau titre"
    await pg_session.commit()
    await publish_job(pg_session, job.id, claude_calls=0)
    await pg_session.commit()
    await pg_session.refresh(item)
    assert (item.start_page, item.end_page, item.chapter_title) == (40, 45, "Nouveau titre")


async def test_changed_item_keeps_item_id_replaces_cards(pg_session):
    _, college, job = await _setup(pg_session)
    item = await make_item(pg_session, college, 304, text="ancien texte")
    old = await make_card(pg_session, item, recto="ancienne")
    await make_draft(pg_session, job, 304, "texte modifié", cards("Nouvelle 1", "Nouvelle 2"))
    await pg_session.commit()

    summary = await publish_job(pg_session, job.id, claude_calls=1)
    await pg_session.commit()

    assert summary.changed == 1
    assert (await pg_session.execute(select(func.count()).select_from(Item))).scalar_one() == 1
    rows = (await pg_session.execute(select(FlashCard))).scalars().all()
    assert {c.recto for c in rows} == {"Nouvelle 1", "Nouvelle 2"}
    assert old.id not in {c.id for c in rows}
    assert all(c.item_id == item.id for c in rows)


async def test_removed_item_is_deleted_with_cards(pg_session):
    _, college, job = await _setup(pg_session)
    gone = await make_item(pg_session, college, 999, text="disparu")
    await make_card(pg_session, gone)
    await make_draft(pg_session, job, 304, "texte", cards("Q"))
    await pg_session.commit()
    summary = await publish_job(pg_session, job.id, claude_calls=1)
    await pg_session.commit()
    assert (summary.removed, summary.added) == (1, 1)
    assert [i.item_number for i in (await pg_session.execute(select(Item))).scalars()] == [304]
    assert {c.recto for c in (await pg_session.execute(select(FlashCard))).scalars()} == {"Q"}


async def test_item_without_generation_is_published_without_cards(pg_session):
    _, college, job = await _setup(pg_session, status="ocr_complete")
    await make_draft(pg_session, job, 304, "texte", None)
    await pg_session.commit()
    summary = await publish_job(pg_session, job.id, claude_calls=1)
    await pg_session.commit()
    assert (summary.added, summary.cards) == (1, 0)
    assert (await pg_session.execute(select(func.count()).select_from(Item))).scalar_one() == 1


async def test_quota_refunded_only_for_reimport_without_claude_call(pg_session):
    user, college, job = await _setup(pg_session, reload_count=1, monthly=1)
    await make_item(pg_session, college, 304, text="même")
    await make_draft(pg_session, job, 304, "même", cards("Q"))
    await pg_session.commit()
    summary = await publish_job(pg_session, job.id, claude_calls=0)
    await pg_session.commit()
    assert summary.quota_refunded is True
    await pg_session.refresh(college)
    await pg_session.refresh(user)
    assert (college.reload_count, user.monthly_reloads) == (0, 0)


async def test_quota_kept_when_claude_was_called(pg_session):
    user, college, job = await _setup(pg_session, reload_count=1, monthly=1)
    await make_draft(pg_session, job, 304, "nouveau", cards("Q"))
    await pg_session.commit()
    summary = await publish_job(pg_session, job.id, claude_calls=3)
    await pg_session.commit()
    assert summary.quota_refunded is False
    await pg_session.refresh(college)
    assert college.reload_count == 1


async def test_first_import_never_refunds(pg_session):
    user, college, job = await _setup(pg_session, status="ocr_complete", reload_count=0, monthly=1)
    await make_draft(pg_session, job, 304, "t", cards("Q"))
    await pg_session.commit()
    summary = await publish_job(pg_session, job.id, claude_calls=0)
    await pg_session.commit()
    assert summary.quota_refunded is False
    await pg_session.refresh(user)
    assert user.monthly_reloads == 1


async def test_second_publish_is_a_noop(pg_session):
    _, college, job = await _setup(pg_session, status="ocr_complete")
    await make_draft(pg_session, job, 304, "t", cards("Q"))
    await pg_session.commit()
    assert await publish_job(pg_session, job.id, claude_calls=1) is not None
    await pg_session.commit()
    assert await publish_job(pg_session, job.id, claude_calls=1) is None
    assert (await pg_session.execute(select(func.count()).select_from(FlashCard))).scalar_one() == 1


async def test_stopped_job_is_not_published(pg_session):
    _, college, job = await _setup(pg_session)
    await make_draft(pg_session, job, 304, "t", cards("Q"))
    job.status = "failed"
    await pg_session.commit()
    assert await publish_job(pg_session, job.id, claude_calls=1) is None
    assert (await pg_session.execute(select(func.count()).select_from(Item))).scalar_one() == 0


async def test_college_pages_replaced_and_draft_cleared(pg_session):
    _, college, job = await _setup(pg_session)
    await make_job_page(pg_session, job, 0, "p0")
    await make_job_page(pg_session, job, 1, "p1")
    await make_draft(pg_session, job, 304, "t", cards("Q"))
    await pg_session.commit()
    await publish_job(pg_session, job.id, claude_calls=1)
    await pg_session.commit()
    pages = (await pg_session.execute(select(CollegePage).order_by(CollegePage.page_number))).scalars().all()
    assert [p.page_number for p in pages] == [0, 1]
    for model in (JobPage, JobItem):
        assert (await pg_session.execute(select(func.count()).select_from(model))).scalar_one() == 0


async def test_summary_persisted_on_job(pg_session):
    _, college, job = await _setup(pg_session)
    await make_draft(pg_session, job, 304, "t", cards("Q"))
    await pg_session.commit()
    await publish_job(pg_session, job.id, claude_calls=1)
    await pg_session.commit()
    await pg_session.refresh(job)
    assert json.loads(job.summary_json) == {
        "changed": 0,
        "added": 1,
        "removed": 0,
        "unchanged": 0,
        "cards": 1,
        "claude_calls": 1,
        "quota_refunded": False,
        "reimport": True,
        "insufficient_items": [],
    }
    assert job.hash_shared is False


def test_stale_pdfs_lists_other_pdfs_of_the_college(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "pdf_storage_path", str(tmp_path))
    college_id, keep, old = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    other_college = uuid.uuid4()
    for name in (f"{college_id}_{keep}.pdf", f"{college_id}_{old}.pdf", f"{other_college}_{old}.pdf"):
        (tmp_path / name).write_bytes(b"%PDF")
    assert [p.name for p in stale_pdfs(college_id, keep)] == [f"{college_id}_{old}.pdf"]


async def test_unchanged_item_without_cards_finally_gets_them(pg_session):
    _, college, job = await _setup(pg_session)
    item = await make_item(pg_session, college, 304, text="même texte")  # publié sans fiche
    await make_draft(pg_session, job, 304, "même texte", cards("Q enfin"))
    await pg_session.commit()
    summary = await publish_job(pg_session, job.id, claude_calls=1)
    await pg_session.commit()
    assert (summary.changed, summary.unchanged) == (1, 0)
    rows = (await pg_session.execute(select(FlashCard))).scalars().all()
    assert [(c.item_id, c.recto) for c in rows] == [(item.id, "Q enfin")]


async def test_changed_item_without_generation_keeps_old_content(pg_session):
    _, college, job = await _setup(pg_session)
    item = await make_item(pg_session, college, 304, text="ancien texte")
    old = await make_card(pg_session, item, recto="ancienne")
    old_hash = item.text_hash
    await make_draft(pg_session, job, 304, "texte modifié", None)  # Claude n'a rien rendu
    await pg_session.commit()
    summary = await publish_job(pg_session, job.id, claude_calls=1)
    await pg_session.commit()
    assert (summary.changed, summary.unchanged) == (0, 1)
    await pg_session.refresh(item)
    assert item.text_hash == old_hash  # retenté au prochain import
    assert [c.id for c in (await pg_session.execute(select(FlashCard))).scalars()] == [old.id]


async def test_reimport_losing_most_items_is_rejected_untouched(pg_session):
    from app.services.generation.publish import ImportRejected

    _, college, job = await _setup(pg_session)
    for n in (301, 302, 303, 304):
        await make_card(pg_session, await make_item(pg_session, college, n, text=f"t{n}"))
    await make_draft(pg_session, job, 304, "t304", cards("Q"))  # 3 items sur 4 disparaîtraient
    await pg_session.commit()
    with pytest.raises(ImportRejected, match="3 items sur 4"):
        await publish_job(pg_session, job.id, claude_calls=1)
    await pg_session.rollback()
    assert (await pg_session.execute(select(func.count()).select_from(Item))).scalar_one() == 4
    assert (await pg_session.execute(select(func.count()).select_from(FlashCard))).scalar_one() == 4


async def test_first_import_is_never_rejected(pg_session):
    _, college, job = await _setup(pg_session, status="ocr_complete")
    await make_draft(pg_session, job, 304, "t", cards("Q"))
    await pg_session.commit()
    assert (await publish_job(pg_session, job.id, claude_calls=1)).reimport is False


async def test_card_rang_is_published_per_card_defaulting_to_item_rang(pg_session):
    _, college, job = await _setup(pg_session, status="ocr_complete")
    await make_draft(
        pg_session,
        job,
        304,
        "texte",
        [
            {"card_type": "classique", "rang": "A", "recto": "QA", "verso": "R"},
            {"card_type": "classique", "rang": "B", "recto": "QB", "verso": "R"},
            {"card_type": "classique", "recto": "Q sans rang", "verso": "R"},  # génération p1
        ],
        rang="B",
    )
    await pg_session.commit()
    await publish_job(pg_session, job.id, claude_calls=1)
    await pg_session.commit()
    rows = (await pg_session.execute(select(FlashCard.recto, FlashCard.rang))).tuples().all()
    assert sorted(rows) == [("Q sans rang", "B"), ("QA", "A"), ("QB", "B")]


async def test_cas_clinique_card_is_accepted_by_the_database(pg_session):
    _, college, job = await _setup(pg_session, status="ocr_complete")
    await make_draft(
        pg_session, job, 304, "texte", [{"card_type": "cas_clinique", "rang": "A", "recto": "Cas ?", "verso": "R"}]
    )
    await pg_session.commit()
    await publish_job(pg_session, job.id, claude_calls=1)
    await pg_session.commit()
    assert (await pg_session.execute(select(FlashCard.card_type))).scalars().all() == ["cas_clinique"]


async def test_summary_lists_insufficient_items_on_first_import(pg_session):
    _, college, job = await _setup(pg_session, status="ocr_complete")
    await make_draft(pg_session, job, 304, "texte", cards("Q"))
    await make_draft(pg_session, job, 305, "sommaire", [], insufficient_text=True)
    await make_draft(pg_session, job, 215, "objectifs seuls", [], insufficient_text=True)
    await pg_session.commit()
    summary = await publish_job(pg_session, job.id, claude_calls=3)
    await pg_session.commit()
    assert summary.insufficient_items == [215, 305]
    assert (summary.added, summary.cards) == (3, 1)
    await pg_session.refresh(job)
    assert json.loads(job.summary_json)["insufficient_items"] == [215, 305]


async def test_unchanged_insufficient_item_counts_as_unchanged(pg_session):
    _, college, job = await _setup(pg_session)
    await make_item(pg_session, college, 305, text="sommaire")  # publié sans fiche
    await make_draft(pg_session, job, 305, "sommaire", [], insufficient_text=True)
    await pg_session.commit()
    summary = await publish_job(pg_session, job.id, claude_calls=0)
    await pg_session.commit()
    assert (summary.changed, summary.unchanged, summary.insufficient_items) == (0, 1, [305])


async def test_changed_item_now_insufficient_keeps_old_content(pg_session):
    _, college, job = await _setup(pg_session)
    item = await make_item(pg_session, college, 304, text="ancien texte")
    old = await make_card(pg_session, item, recto="ancienne")
    await make_draft(pg_session, job, 304, "texte tronqué", [], insufficient_text=True)
    await pg_session.commit()
    summary = await publish_job(pg_session, job.id, claude_calls=1)
    await pg_session.commit()
    assert (summary.changed, summary.unchanged, summary.insufficient_items) == (0, 1, [304])
    assert [c.id for c in (await pg_session.execute(select(FlashCard))).scalars()] == [old.id]
