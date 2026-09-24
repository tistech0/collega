"""Tests GET /v1/tester/colleges/{id}/summary — résumé des feedbacks par item."""

from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock

from httpx import AsyncClient

TESTER_AUTH = ("tester", "testpass")


def make_college(college_id=None):
    return types.SimpleNamespace(id=college_id or uuid.uuid4(), college_ref_id=2)


def make_item(item_id=None, college_id=None, item_number=1, rang="A"):
    return types.SimpleNamespace(
        id=item_id or uuid.uuid4(),
        college_id=college_id or uuid.uuid4(),
        item_number=item_number,
        rang=rang,
        chapter_title=None,
    )


def make_feedback(is_pertinent=True):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        is_pertinent=is_pertinent,
        tester_id="tester",
    )


class TestGetCollegeSummary:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.get(f"/v1/tester/colleges/{uuid.uuid4()}/summary")
        assert resp.status_code == 401

    async def test_404_for_unknown_college(self, client: AsyncClient, mock_db):
        mock_db.get = AsyncMock(return_value=None)
        resp = await client.get(f"/v1/tester/colleges/{uuid.uuid4()}/summary", auth=TESTER_AUTH)
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "COLLEGE_NOT_FOUND"

    async def test_summary_with_no_items(self, client: AsyncClient, mock_db):
        college_id = uuid.uuid4()
        college = make_college(college_id=college_id)
        mock_db.get = AsyncMock(return_value=college)
        # SELECT items → vide
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[]))))
        )
        resp = await client.get(f"/v1/tester/colleges/{college_id}/summary", auth=TESTER_AUTH)
        assert resp.status_code == 200
        assert resp.json()["data"]["items"] == []

    async def test_summary_counts_correctly(self, client: AsyncClient, mock_db):
        """2 fiches pertinentes, 1 non pertinente, 2 en attente → totaux corrects."""
        college_id = uuid.uuid4()
        college = make_college(college_id=college_id)
        item_id = uuid.uuid4()
        item = make_item(item_id=item_id, college_id=college_id, item_number=1, rang="A")
        card_ids = [uuid.uuid4() for _ in range(5)]

        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(
            side_effect=[
                # SELECT Item → [item]
                MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[item])))),
                # SELECT FlashCard.id where item_id → card_ids
                MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=card_ids)))),
                # SELECT TesterFeedback where in card_ids → 3 feedbacks (2 pertinent, 1 non)
                MagicMock(
                    scalars=MagicMock(
                        return_value=MagicMock(
                            all=MagicMock(
                                return_value=[
                                    make_feedback(is_pertinent=True),
                                    make_feedback(is_pertinent=True),
                                    make_feedback(is_pertinent=False),
                                ]
                            )
                        )
                    )
                ),
            ]
        )

        resp = await client.get(f"/v1/tester/colleges/{college_id}/summary", auth=TESTER_AUTH)
        assert resp.status_code == 200
        summary = resp.json()["data"]["items"][0]
        assert summary["item_number"] == 1
        assert summary["rang"] == "A"
        assert summary["total_cards"] == 5
        assert summary["pertinent_count"] == 2
        assert summary["not_pertinent_count"] == 1
        assert summary["pending_count"] == 2  # 5 - 3

    async def test_summary_all_pending(self, client: AsyncClient, mock_db):
        """Aucun feedback — toutes les fiches sont en attente."""
        college_id = uuid.uuid4()
        college = make_college(college_id=college_id)
        item = make_item(college_id=college_id)
        card_ids = [uuid.uuid4(), uuid.uuid4(), uuid.uuid4()]

        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(
            side_effect=[
                MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[item])))),
                MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=card_ids)))),
                MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[])))),
            ]
        )

        resp = await client.get(f"/v1/tester/colleges/{college_id}/summary", auth=TESTER_AUTH)
        summary = resp.json()["data"]["items"][0]
        assert summary["total_cards"] == 3
        assert summary["pertinent_count"] == 0
        assert summary["not_pertinent_count"] == 0
        assert summary["pending_count"] == 3

    async def test_response_has_data_wrapper(self, client: AsyncClient, mock_db):
        college_id = uuid.uuid4()
        college = make_college(college_id=college_id)
        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[]))))
        )
        resp = await client.get(f"/v1/tester/colleges/{college_id}/summary", auth=TESTER_AUTH)
        assert "data" in resp.json()
        assert "college_id" in resp.json()["data"]
