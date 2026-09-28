import pytest
from sqlalchemy import text

pytestmark = pytest.mark.pg


async def test_schema_is_migrated_to_head(pg_session):
    version = (await pg_session.execute(text("select version_num from alembic_version"))).scalar_one()
    assert version == "022"
