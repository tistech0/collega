---
type: "Gotcha"
title: "Migration 022 added users.last_seen_at and the activity_days table (console de pilotage, t"
description: "Migration 022 added users.last seen at and the activity days table console de pilotage, task 1 . Two gotchas for future alembic migrations here: 1 alembic check compares the ORM model against the migration's actual DDL —"
resource: "collega_backend/app/models/activity_day.py"
tags: ["session-learning", "alembic", "migration", "gotcha", "testing"]
timestamp: "2026-09-26T14:55:26.385Z"
x-kage-id: "repo:git-github-com-tistech0-collega:gotcha:migration-022-added-users-last-seen-at-and-the-activity-days-table-console-de-pi"
x-kage-type: "gotcha"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_backend/app/models/activity_day.py", "collega_backend/alembic/versions/022_activity_last_seen.py", "collega_backend/tests/db/test_pg_fixture.py"]
---

# Migration 022 added users.last_seen_at and the activity_days table (console de pilotage, t

> Migration 022 added users.last seen at and the activity days table console de pilotage, task 1 . Two gotchas for futu…

Migration 022 added users.last_seen_at and the activity_days table (console de pilotage, task 1). Two gotchas for future alembic migrations here: (1) `alembic check` compares the ORM model against the migration's actual DDL — a column with `server_default=sa.text("now()")` in the migration needs the matching `server_default=func.now()` on the SQLAlchemy model column (not just a Python-side `default=`), otherwise `alembic check` reports a spurious diff; align the model, never the migration. (2) tests/db/test_pg_fixture.py::test_schema_is_migrated_to_head hardcodes the expected alembic head revision string (e.g. "021"); every new migration must bump that literal in the same commit or the full test suite fails even though the new migration/model pair is correct.
Evidence: alembic check against collega_check DB printed 'No new upgrade operations detected.' only after adding server_default=func.now() to ActivityDay.updated_at; pytest -q failed with 1 failed (test_pg_fixture.py assert version == '021') until bumped to '022', then 963 passed.

## Verification

alembic check against collega_check DB printed 'No new upgrade operations detected.' only after adding server_default=func.now() to ActivityDay.updated_at; pytest -q failed with 1 failed (test_pg_fixture.py assert version == '021') until bumped to '022', then 963 passed.

# Citations

[1] explicit_capture (2026-09-26T14:55:26.385Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:gotcha:migration-022-added-users-last-seen-at-and-the-activity-days-table-console-de-pi","title":"Migration 022 added users.last_seen_at and the activity_days table (console de pilotage, t","summary":"Migration 022 added users.last seen at and the activity days table console de pilotage, task 1 . Two gotchas for future alembic migrations here: 1 alembic check compares the ORM model against the migration's actual DDL —","body":"Migration 022 added users.last_seen_at and the activity_days table (console de pilotage, task 1). Two gotchas for future alembic migrations here: (1) `alembic check` compares the ORM model against the migration's actual DDL — a column with `server_default=sa.text(\"now()\")` in the migration needs the matching `server_default=func.now()` on the SQLAlchemy model column (not just a Python-side `default=`), otherwise `alembic check` reports a spurious diff; align the model, never the migration. (2) tests/db/test_pg_fixture.py::test_schema_is_migrated_to_head hardcodes the expected alembic head revision string (e.g. \"021\"); every new migration must bump that literal in the same commit or the full test suite fails even though the new migration/model pair is correct.\nEvidence: alembic check against collega_check DB printed 'No new upgrade operations detected.' only after adding server_default=func.now() to ActivityDay.updated_at; pytest -q failed with 1 failed (test_pg_fixture.py assert version == '021') until bumped to '022', then 963 passed.","type":"gotcha","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","alembic","migration","gotcha","testing"],"paths":["collega_backend/app/models/activity_day.py","collega_backend/alembic/versions/022_activity_last_seen.py","collega_backend/tests/db/test_pg_fixture.py"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-26T14:55:26.385Z"}],"context":{"fact":"Migration 022 added users.last_seen_at and the activity_days table (console de pilotage, task 1). Two gotchas for future alembic migrations here: (1) `alembic check` compares the ORM model against the migration's actual DDL — a column with `server_default=sa.text(\"now()\")` in the migration needs the matching `server_default=func.now()` on the SQLAlchemy model column (not just a Python-side `default=`), otherwise `alembic check` reports a spurious diff; align the model, never the migration. (2) tests/db/test_pg_fixture.py::test_schema_is_migrated_to_head hardcodes the expected alembic head revision string (e.g. \"021\"); every new migration must bump that literal in the same commit or the full test suite fails even though the new migration/model pair is correct.\nEvidence: alembic check against collega_check DB printed 'No new upgrade operations detected.' only after adding server_default=func.now() to ActivityDay.updated_at; pytest -q failed with 1 failed (test_pg_fixture.py assert version == '021') until bumped to '022', then 963 passed.","verification":"alembic check against collega_check DB printed 'No new upgrade operations detected.' only after adding server_default=func.now() to ActivityDay.updated_at; pytest -q failed with 1 failed (test_pg_fixture.py assert version == '021') until bumped to '022', then 963 passed."},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-26T14:55:26.385Z","path_fingerprints":[{"path":"collega_backend/app/models/activity_day.py","sha256":"ca88b09688b90477895700a9afe0aac1a9115584c6e80c8e10ce15e7497b683b","size":1421},{"path":"collega_backend/alembic/versions/022_activity_last_seen.py","sha256":"62bb05c2d5f76595e9fd2a0a71e4692e1c2623a84c4b5c43447f56984c1d8ee4","size":1283},{"path":"collega_backend/tests/db/test_pg_fixture.py","sha256":"1d64a018fbdf4d1e1e9fd8b76d2c023d94e4ed181551ef5e9ff8f259111eec8a","size":259}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":17,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":8000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":263,"total_uses":17,"last_accessed_at":"2026-09-26T16:39:12.263Z"},"created_at":"2026-09-26T14:55:26.385Z","updated_at":"2026-09-26T14:55:26.385Z","author_branch":"feat/console-pilotage"}
```

