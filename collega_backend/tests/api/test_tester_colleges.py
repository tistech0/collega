"""Tests GET /v1/tester/colleges — liste des collèges disponibles pour le testeur."""
from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

TESTER_AUTH = ("tester", "testpass")


def make_college(college_id=None, college_ref_id=5):
    return types.SimpleNamespace(id=college_id or uuid.uuid4(), college_ref_id=college_ref_id)


class TestListColleges:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.get("/v1/tester/colleges")
        assert resp.status_code == 401

    async def test_401_with_admin_credentials(self, client: AsyncClient):
        """Les credentials admin ne donnent pas accès aux routes testeur."""
        resp = await client.get("/v1/tester/colleges", auth=("admin", "testpass"))
        assert resp.status_code == 401

    async def test_empty_list_when_no_generation_complete(self, client: AsyncClient, mock_db):
        """Aucun job generation_complete → liste vide."""
        # SELECT college_ids avec generation_complete → vide
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[]))))
        )
        resp = await client.get("/v1/tester/colleges", auth=TESTER_AUTH)
        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 0
        assert body["data"] == []

    async def test_lists_colleges_with_generation_complete(self, client: AsyncClient, mock_db):
        """Un collège avec job generation_complete est retourné."""
        college_id = uuid.uuid4()
        college = make_college(college_id=college_id, college_ref_id=7)

        # Appels execute dans l'ordre :
        # 1. SELECT college_ids → [college_id]
        # 2. SELECT College.where(in) → [college]
        # 3. SELECT count(FlashCard) → 10
        # 4. SELECT count(TesterFeedback) → 3
        mock_db.execute = AsyncMock(side_effect=[
            MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[college_id])))),
            MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[college])))),
            MagicMock(scalar_one=MagicMock(return_value=10)),
            MagicMock(scalar_one=MagicMock(return_value=3)),
        ])

        resp = await client.get("/v1/tester/colleges", auth=TESTER_AUTH)
        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 1
        assert body["data"][0]["college_ref_id"] == 7
        assert body["data"][0]["card_count"] == 10
        assert body["data"][0]["feedback_count"] == 3

    async def test_response_has_data_wrapper(self, client: AsyncClient, mock_db):
        mock_db.execute = AsyncMock(
            return_value=MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[]))))
        )
        resp = await client.get("/v1/tester/colleges", auth=TESTER_AUTH)
        assert "data" in resp.json()
        assert "total" in resp.json()
