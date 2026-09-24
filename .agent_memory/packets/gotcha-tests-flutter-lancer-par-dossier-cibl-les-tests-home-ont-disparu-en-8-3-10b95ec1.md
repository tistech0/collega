---
type: "Gotcha"
title: "Tests Flutter : lancer par dossier ciblé ; les tests home ont disparu en 8.3"
description: "Les tests test/features/home home notifier, home screen ont été supprimés avec l'écran Home en story 8.3 remplacé par Aujourd'hui, test/features/today . Convention du projet : ne jamais lancer flutter test global, toujou"
resource: "collega_app/test/features/today/today_provider_test.dart"
tags: ["session-learning", "audit-2026-09-23"]
timestamp: "2026-09-23T15:53:45.699Z"
x-kage-id: "repo:git-github-com-tistech0-collega:gotcha:tests-flutter-lancer-par-dossier-cibl-les-tests-home-ont-disparu-en-8-3-17901788"
x-kage-type: "gotcha"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_app/test/features/today/today_provider_test.dart", "collega_app/test/features/profile/profile_screen_test.dart", "collega_app/test/features/search/search_notifier_test.dart"]
---

# Tests Flutter : lancer par dossier ciblé ; les tests home ont disparu en 8.3

> Les tests test/features/home home notifier, home screen ont été supprimés avec l'écran Home en story 8.3 remplacé par…

Les tests test/features/home (home_notifier, home_screen) ont été supprimés avec l'écran Home en story 8.3 (remplacé par Aujourd'hui, test/features/today). Convention du projet : ne jamais lancer `flutter test` global, toujours par dossiers ciblés (ex. `flutter test test/features/drill test/features/today`, puis `test/features/colleges test/features/search test/features/profile test/core`, puis `test/features/shell test/features/planning test/features/progress test/features/demo test/features/auth test/features/legal`). Il n'existe ni dossier test/features/item_detail ni test/features/generation (supprimé en 8.10-8.11) : les passer à flutter test compte comme un échec de chargement.
Verified by: ls collega_app/test/features ; runs ciblés du 2026-09-22 (231 + 590 + 63 verts) ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)

## Verification

ls collega_app/test/features ; runs ciblés du 2026-09-22 (231 + 590 + 63 verts) ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)

# Citations

[1] explicit_capture (2026-09-23T15:53:45.699Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:gotcha:tests-flutter-lancer-par-dossier-cibl-les-tests-home-ont-disparu-en-8-3-17901788","title":"Tests Flutter : lancer par dossier ciblé ; les tests home ont disparu en 8.3","summary":"Les tests test/features/home home notifier, home screen ont été supprimés avec l'écran Home en story 8.3 remplacé par Aujourd'hui, test/features/today . Convention du projet : ne jamais lancer flutter test global, toujou","body":"Les tests test/features/home (home_notifier, home_screen) ont été supprimés avec l'écran Home en story 8.3 (remplacé par Aujourd'hui, test/features/today). Convention du projet : ne jamais lancer `flutter test` global, toujours par dossiers ciblés (ex. `flutter test test/features/drill test/features/today`, puis `test/features/colleges test/features/search test/features/profile test/core`, puis `test/features/shell test/features/planning test/features/progress test/features/demo test/features/auth test/features/legal`). Il n'existe ni dossier test/features/item_detail ni test/features/generation (supprimé en 8.10-8.11) : les passer à flutter test compte comme un échec de chargement.\nVerified by: ls collega_app/test/features ; runs ciblés du 2026-09-22 (231 + 590 + 63 verts) ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)","type":"gotcha","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","audit-2026-09-23"],"paths":["collega_app/test/features/today/today_provider_test.dart","collega_app/test/features/profile/profile_screen_test.dart","collega_app/test/features/search/search_notifier_test.dart"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-23T15:53:45.699Z"}],"context":{"fact":"Les tests test/features/home (home_notifier, home_screen) ont été supprimés avec l'écran Home en story 8.3 (remplacé par Aujourd'hui, test/features/today). Convention du projet : ne jamais lancer `flutter test` global, toujours par dossiers ciblés (ex. `flutter test test/features/drill test/features/today`, puis `test/features/colleges test/features/search test/features/profile test/core`, puis `test/features/shell test/features/planning test/features/progress test/features/demo test/features/auth test/features/legal`). Il n'existe ni dossier test/features/item_detail ni test/features/generation (supprimé en 8.10-8.11) : les passer à flutter test compte comme un échec de chargement.\nVerified by: ls collega_app/test/features ; runs ciblés du 2026-09-22 (231 + 590 + 63 verts) ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)","verification":"ls collega_app/test/features ; runs ciblés du 2026-09-22 (231 + 590 + 63 verts) ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)"},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T15:53:45.699Z","path_fingerprints":[{"path":"collega_app/test/features/today/today_provider_test.dart","sha256":"edc31b96c19128969e40dcdc67afc2d493c7a77f5c27d101186fa5ff2e84f4af","size":11185},{"path":"collega_app/test/features/profile/profile_screen_test.dart","sha256":"6c8daf4c2a3f0a6b86103db1735afef9954a3bc618aab4d752b9305e139417ec","size":22633},{"path":"collega_app/test/features/search/search_notifier_test.dart","sha256":"2d4c79c69a96c07f33028f57cfe06e0e513ce3a94b91e7f3e8227eab1d1d398a","size":6603}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[{"relation":"supersedes","to":"repo:git-github-com-tistech0-collega:gotcha:tests-flutter-lancer-par-dossier-cibl-les-tests-home-ont-disparu-en-8-3-17901124","evidence":"Revérifié contre main 560e503 (audit 2026-09-23) : passages périmés corrigés","created_at":"2026-09-23T15:53:46.078Z"}],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":1,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":8000,"discovery_tokens_estimated":true,"score":86,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":["possible duplicate memory"],"duplicate_candidates":[{"id":"repo:git-github-com-tistech0-collega:gotcha:tests-flutter-lancer-par-dossier-cibl-les-tests-home-ont-disparu-en-8-3-17901124","title":"Tests Flutter : lancer par dossier ciblé ; les tests home ont disparu en 8.3","score":0.69,"status":"approved"}],"estimated_tokens_saved":218,"total_uses":1,"last_accessed_at":"2026-09-23T20:06:13.328Z"},"created_at":"2026-09-23T15:53:45.699Z","updated_at":"2026-09-23T15:53:46.078Z","author_branch":"main"}
```

