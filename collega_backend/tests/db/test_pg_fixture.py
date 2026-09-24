import pytest
from sqlalchemy import text

from tests.pg import pg_engine, pg_factory, pg_session  # noqa: F401

pytestmark = pytest.mark.pg


async def test_schema_is_migrated_to_head(pg_session):
    version = (await pg_session.execute(text("select version_num from alembic_version"))).scalar_one()
    assert version == "018"
