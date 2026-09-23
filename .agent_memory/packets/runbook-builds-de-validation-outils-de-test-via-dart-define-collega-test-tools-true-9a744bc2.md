---
type: "Runbook"
title: "Builds de validation : outils de test via --dart-define=COLLEGA_TEST_TOOLS=true"
description: "kTestTools collega app/lib/env.dart, bool.fromEnvironment 'COLLEGA TEST TOOLS' active des outils de validation absents des builds publiés. Premier outil : « Test : réinitialiser la session du jour » dans la vue du Planni"
resource: "collega_app/lib/env.dart"
tags: ["session-learning"]
timestamp: "2026-09-23T10:42:39.045Z"
x-kage-id: "repo:git-github-com-tistech0-collega:runbook:builds-de-validation-outils-de-test-via-dart-define-collega-test-tools-true-1790"
x-kage-type: "runbook"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "verified"
x-kage-paths: ["collega_app/lib/env.dart", "collega_app/lib/features/today/data/daily_session_repository.dart", "collega_app/lib/features/planning/presentation/planning_screen.dart", "collega_app/tool/run_device.sh"]
---

# Builds de validation : outils de test via --dart-define=COLLEGA_TEST_TOOLS=true

> kTestTools collega app/lib/env.dart, bool.fromEnvironment 'COLLEGA TEST TOOLS' active des outils de validation absent…

`kTestTools` (collega_app/lib/env.dart, `bool.fromEnvironment('COLLEGA_TEST_TOOLS')`) active des outils de validation absents des builds publiés. Premier outil : « Test : réinitialiser la session du jour » dans la vue du Planning (`DailySessionRepository.resetDay` : supprime la session du jour et ses verdicts `daily`, garde les autres révisions) — pour tester « Décaler aujourd'hui » quand la session du jour est déjà faite. Build iPhone de validation : `collega_app/tool/run_device.sh --release -d 00008110-000115D43499801E --dart-define=COLLEGA_TEST_TOOLS=true`.
Verified by: test daily_session_repository_test « resetDay » + flutter analyze

## Verification

test daily_session_repository_test « resetDay » + flutter analyze

# Citations

[1] explicit_capture (2026-09-23T08:33:10.925Z)
[2] reverification

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:runbook:builds-de-validation-outils-de-test-via-dart-define-collega-test-tools-true-1790","title":"Builds de validation : outils de test via --dart-define=COLLEGA_TEST_TOOLS=true","summary":"kTestTools collega app/lib/env.dart, bool.fromEnvironment 'COLLEGA TEST TOOLS' active des outils de validation absents des builds publiés. Premier outil : « Test : réinitialiser la session du jour » dans la vue du Planni","body":"`kTestTools` (collega_app/lib/env.dart, `bool.fromEnvironment('COLLEGA_TEST_TOOLS')`) active des outils de validation absents des builds publiés. Premier outil : « Test : réinitialiser la session du jour » dans la vue du Planning (`DailySessionRepository.resetDay` : supprime la session du jour et ses verdicts `daily`, garde les autres révisions) — pour tester « Décaler aujourd'hui » quand la session du jour est déjà faite. Build iPhone de validation : `collega_app/tool/run_device.sh --release -d 00008110-000115D43499801E --dart-define=COLLEGA_TEST_TOOLS=true`.\nVerified by: test daily_session_repository_test « resetDay » + flutter analyze","type":"runbook","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning"],"paths":["collega_app/lib/env.dart","collega_app/lib/features/today/data/daily_session_repository.dart","collega_app/lib/features/planning/presentation/planning_screen.dart","collega_app/tool/run_device.sh"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-23T08:33:10.925Z"},{"kind":"reverification","at":"2026-09-23T10:42:39.045Z","evidence":"env.dart only gained kAppVersion; kTestTools = bool.fromEnvironment('COLLEGA_TEST_TOOLS') unchanged","changed_paths":[{"path":"collega_app/lib/env.dart","prior_sha256":"0b37658e34c4c5f204a908ebd95f8ca1ab5eafe46163a8b7fc73684f895de146","sha256":"978e70c88dc89a6ec3257fa2fc7b8fa9de5de193f8cebe8d748a0f031b56bb5a"}]}],"context":{"fact":"`kTestTools` (collega_app/lib/env.dart, `bool.fromEnvironment('COLLEGA_TEST_TOOLS')`) active des outils de validation absents des builds publiés. Premier outil : « Test : réinitialiser la session du jour » dans la vue du Planning (`DailySessionRepository.resetDay` : supprime la session du jour et ses verdicts `daily`, garde les autres révisions) — pour tester « Décaler aujourd'hui » quand la session du jour est déjà faite. Build iPhone de validation : `collega_app/tool/run_device.sh --release -d 00008110-000115D43499801E --dart-define=COLLEGA_TEST_TOOLS=true`.\nVerified by: test daily_session_repository_test « resetDay » + flutter analyze","verification":"test daily_session_repository_test « resetDay » + flutter analyze"},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T10:42:39.045Z","path_fingerprints":[{"path":"collega_app/lib/env.dart","sha256":"978e70c88dc89a6ec3257fa2fc7b8fa9de5de193f8cebe8d748a0f031b56bb5a","size":1161},{"path":"collega_app/lib/features/today/data/daily_session_repository.dart","sha256":"152d7e080a7f93258d4ae527b713c6c884947051abd64833e917f5f900be6d9d","size":10857},{"path":"collega_app/lib/features/planning/presentation/planning_screen.dart","sha256":"06263bd592b1ea8b838c2232ac1a26fcf493867df1f08616f0c2ac232f306399","size":23708},{"path":"collega_app/tool/run_device.sh","sha256":"29bee8a98981f183058a6fdbf3491a0ba8c42657e45b62a99bfa3ad6f3680fef","size":868}],"path_fingerprint_policy":"source_hash_staleness","verification":"evidence_reverification"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":7,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":2000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":162,"reverified_at":"2026-09-23T10:42:39.045Z","total_uses":7,"last_accessed_at":"2026-09-23T16:06:17.708Z"},"created_at":"2026-09-23T08:33:10.925Z","updated_at":"2026-09-23T10:42:39.045Z","author_branch":"feat/redesign-ux-ui"}
```

