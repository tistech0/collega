---
type: "Gotcha"
title: "pytest's default `python_functions` ini option is the literal string `test` (not the glob"
description: "pytest's default python functions ini option is the literal string test not the glob test , and pytest collects any module level callable whose name merely starts with \"test\" — not just names starting with \"test \". So im"
resource: "collega_backend/tests/api/test_admin_pilot_pg.py"
tags: ["session-learning", "pytest", "test-collection", "gotcha", "python_functions"]
timestamp: "2026-09-26T15:35:58.124Z"
x-kage-id: "repo:git-github-com-tistech0-collega:gotcha:pytests-default-python-functions-ini-option-is-the-literal-string-test-not-the-g"
x-kage-type: "gotcha"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "stale"
x-kage-paths: ["collega_backend/tests/api/test_admin_pilot_pg.py"]
---

# pytest's default `python_functions` ini option is the literal string `test` (not the glob

> pytest's default python functions ini option is the literal string test not the glob test , and pytest collects any m…

pytest's default `python_functions` ini option is the literal string `test` (not the glob `test_*`), and pytest collects any module-level callable whose name merely *starts with* "test" — not just names starting with "test_". So importing a function like `tester_status` (from app.services.admin_pilot) at module level in a test file causes pytest to collect it as its own test item (separate from a differently-named `test_tester_status` wrapper), and it errors at setup because its parameters (e.g. `last_seen_at`, `now`, `inactivity_days`) are mistaken for fixture names. Fix: right after importing such a name, set `<name>.__test__ = False` (e.g. `tester_status.__test__ = False`) to opt it out of collection. This bit tests/api/test_admin_pilot_pg.py exactly as specified in the Task 4 brief for the console de pilotage.
Evidence: `.venv/bin/python -m pytest tests/api/test_admin_pilot_pg.py --collect-only -q` listed both `tester_status` and `test_tester_status` as separate items; running the file produced `ERROR at setup of tester_status ... fixture 'last_seen_at' not found` until `tester_status.__test__ = False` was added.
Verified by: pytest --collect-only output and subsequent green run (8 passed) after the fix

## Verification

`.venv/bin/python -m pytest tests/api/test_admin_pilot_pg.py --collect-only -q` listed both `tester_status` and `test_tester_status` as separate items; running the file produced `ERROR at setup of tester_status ... fixture 'last_seen_at' not found` until `tester_status.__test__ = False` was added.

# Citations

[1] explicit_capture (2026-09-26T15:35:58.124Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:gotcha:pytests-default-python-functions-ini-option-is-the-literal-string-test-not-the-g","title":"pytest's default `python_functions` ini option is the literal string `test` (not the glob","summary":"pytest's default python functions ini option is the literal string test not the glob test , and pytest collects any module level callable whose name merely starts with \"test\" — not just names starting with \"test \". So im","body":"pytest's default `python_functions` ini option is the literal string `test` (not the glob `test_*`), and pytest collects any module-level callable whose name merely *starts with* \"test\" — not just names starting with \"test_\". So importing a function like `tester_status` (from app.services.admin_pilot) at module level in a test file causes pytest to collect it as its own test item (separate from a differently-named `test_tester_status` wrapper), and it errors at setup because its parameters (e.g. `last_seen_at`, `now`, `inactivity_days`) are mistaken for fixture names. Fix: right after importing such a name, set `<name>.__test__ = False` (e.g. `tester_status.__test__ = False`) to opt it out of collection. This bit tests/api/test_admin_pilot_pg.py exactly as specified in the Task 4 brief for the console de pilotage.\nEvidence: `.venv/bin/python -m pytest tests/api/test_admin_pilot_pg.py --collect-only -q` listed both `tester_status` and `test_tester_status` as separate items; running the file produced `ERROR at setup of tester_status ... fixture 'last_seen_at' not found` until `tester_status.__test__ = False` was added.\nVerified by: pytest --collect-only output and subsequent green run (8 passed) after the fix","type":"gotcha","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","pytest","test-collection","gotcha","python_functions"],"paths":["collega_backend/tests/api/test_admin_pilot_pg.py"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-26T15:35:58.124Z"}],"context":{"fact":"pytest's default `python_functions` ini option is the literal string `test` (not the glob `test_*`), and pytest collects any module-level callable whose name merely *starts with* \"test\" — not just names starting with \"test_\". So importing a function like `tester_status` (from app.services.admin_pilot) at module level in a test file causes pytest to collect it as its own test item (separate from a differently-named `test_tester_status` wrapper), and it errors at setup because its parameters (e.g. `last_seen_at`, `now`, `inactivity_days`) are mistaken for fixture names. Fix: right after importing such a name, set `<name>.__test__ = False` (e.g. `tester_status.__test__ = False`) to opt it out of collection. This bit tests/api/test_admin_pilot_pg.py exactly as specified in the Task 4 brief for the console de pilotage.\nEvidence: `.venv/bin/python -m pytest tests/api/test_admin_pilot_pg.py --collect-only -q` listed both `tester_status` and `test_tester_status` as separate items; running the file produced `ERROR at setup of tester_status ... fixture 'last_seen_at' not found` until `tester_status.__test__ = False` was added.\nVerified by: pytest --collect-only output and subsequent green run (8 passed) after the fix","verification":"`.venv/bin/python -m pytest tests/api/test_admin_pilot_pg.py --collect-only -q` listed both `tester_status` and `test_tester_status` as separate items; running the file produced `ERROR at setup of tester_status ... fixture 'last_seen_at' not found` until `tester_status.__test__ = False` was added."},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-26T15:35:58.124Z","path_fingerprints":[{"path":"collega_backend/tests/api/test_admin_pilot_pg.py","sha256":"213504173040a7fc29697e0a2230b920b156426bb77dee57942af265f8492064","size":8413}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":8000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"stale_reasons":["linked path changed since memory was verified: collega_backend/tests/api/test_admin_pilot_pg.py"],"estimated_tokens_saved":307,"stale":true,"suggested_action":"update","total_uses":0},"created_at":"2026-09-26T15:35:58.124Z","updated_at":"2026-09-26T15:35:58.124Z","author_branch":"feat/console-pilotage"}
```

