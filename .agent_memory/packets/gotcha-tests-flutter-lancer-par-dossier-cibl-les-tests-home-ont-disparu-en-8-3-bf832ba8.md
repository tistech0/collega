---
type: "Gotcha"
title: "Tests Flutter : lancer par dossier ciblé ; les tests home ont disparu en 8.3"
description: "Les tests test/features/home home notifier, home screen ont été supprimés avec l'écran Home en story 8.3 remplacé par Aujourd'hui, test/features/today . Convention du projet : ne jamais lancer flutter test global, toujou"
resource: "collega_app/test/features/today/today_provider_test.dart"
tags: ["session-learning"]
timestamp: "2026-09-23T08:27:32.954Z"
x-kage-id: "repo:git-github-com-tistech0-collega:gotcha:tests-flutter-lancer-par-dossier-cibl-les-tests-home-ont-disparu-en-8-3-17901124"
x-kage-type: "gotcha"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "verified"
x-kage-paths: ["collega_app/test/features/today/today_provider_test.dart", "collega_app/test/features/profile/profile_screen_test.dart", "collega_app/test/features/search/search_notifier_test.dart"]
---

# Tests Flutter : lancer par dossier ciblé ; les tests home ont disparu en 8.3

> Les tests test/features/home home notifier, home screen ont été supprimés avec l'écran Home en story 8.3 remplacé par…

Les tests test/features/home (home_notifier, home_screen) ont été supprimés avec l'écran Home en story 8.3 (remplacé par Aujourd'hui, test/features/today). Convention du projet : ne jamais lancer `flutter test` global, toujours par dossiers ciblés (ex. `flutter test test/features/drill test/features/today`, puis colleges/search/profile/core, puis shell/planning/demo/auth/generation). Il n'existe pas de dossier test/features/item_detail : le passer à flutter test compte comme un échec de chargement.
Verified by: ls collega_app/test/features ; runs ciblés du 2026-09-22 (231 + 590 + 63 verts)

## Verification

ls collega_app/test/features ; runs ciblés du 2026-09-22 (231 + 590 + 63 verts)

# Citations

[1] explicit_capture (2026-09-22T21:28:11.178Z)
[2] reverification

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:gotcha:tests-flutter-lancer-par-dossier-cibl-les-tests-home-ont-disparu-en-8-3-17901124","title":"Tests Flutter : lancer par dossier ciblé ; les tests home ont disparu en 8.3","summary":"Les tests test/features/home home notifier, home screen ont été supprimés avec l'écran Home en story 8.3 remplacé par Aujourd'hui, test/features/today . Convention du projet : ne jamais lancer flutter test global, toujou","body":"Les tests test/features/home (home_notifier, home_screen) ont été supprimés avec l'écran Home en story 8.3 (remplacé par Aujourd'hui, test/features/today). Convention du projet : ne jamais lancer `flutter test` global, toujours par dossiers ciblés (ex. `flutter test test/features/drill test/features/today`, puis colleges/search/profile/core, puis shell/planning/demo/auth/generation). Il n'existe pas de dossier test/features/item_detail : le passer à flutter test compte comme un échec de chargement.\nVerified by: ls collega_app/test/features ; runs ciblés du 2026-09-22 (231 + 590 + 63 verts)","type":"gotcha","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning"],"paths":["collega_app/test/features/today/today_provider_test.dart","collega_app/test/features/profile/profile_screen_test.dart","collega_app/test/features/search/search_notifier_test.dart"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-22T21:28:11.178Z"},{"kind":"reverification","at":"2026-09-23T08:27:32.954Z","evidence":"stories 8.8-8.9 (1cb63e6) : comportement décrit inchangé ; tests planning/progress/today/drill/colleges verts","changed_paths":[{"path":"collega_app/test/features/today/today_provider_test.dart","prior_sha256":"a4331aa7132c2f631f1084988de9cc3a9f42628620f74b9f23bcfd41becb4b20","sha256":"edc31b96c19128969e40dcdc67afc2d493c7a77f5c27d101186fa5ff2e84f4af"}]}],"context":{"fact":"Les tests test/features/home (home_notifier, home_screen) ont été supprimés avec l'écran Home en story 8.3 (remplacé par Aujourd'hui, test/features/today). Convention du projet : ne jamais lancer `flutter test` global, toujours par dossiers ciblés (ex. `flutter test test/features/drill test/features/today`, puis colleges/search/profile/core, puis shell/planning/demo/auth/generation). Il n'existe pas de dossier test/features/item_detail : le passer à flutter test compte comme un échec de chargement.\nVerified by: ls collega_app/test/features ; runs ciblés du 2026-09-22 (231 + 590 + 63 verts)","verification":"ls collega_app/test/features ; runs ciblés du 2026-09-22 (231 + 590 + 63 verts)"},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T08:27:32.954Z","path_fingerprints":[{"path":"collega_app/test/features/today/today_provider_test.dart","sha256":"edc31b96c19128969e40dcdc67afc2d493c7a77f5c27d101186fa5ff2e84f4af","size":11185},{"path":"collega_app/test/features/profile/profile_screen_test.dart","sha256":"01eea89b3878a8578643233f5129978d6c74059389ef7d215d65d7884bc82101","size":12452},{"path":"collega_app/test/features/search/search_notifier_test.dart","sha256":"19abcdd8fd5884959d9745aac3a5de78f20abb4189cc86fc34fb5893e5b97d1e","size":3457}],"path_fingerprint_policy":"source_hash_staleness","verification":"evidence_reverification"},"edges":[{"relation":"supersedes","to":"repo:git-github-com-tistech0-collega:gotcha:flutter-test-complet-pas-vert-home-notifier-binding-home-screen-timer-blocage-ap","evidence":"Tests home supprimés en 8.3 avec l'écran Home","created_at":"2026-09-22T21:28:19.215Z"}],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":8000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":149,"reverified_at":"2026-09-23T08:27:32.954Z"},"created_at":"2026-09-22T21:28:11.178Z","updated_at":"2026-09-23T08:27:32.954Z","author_branch":"feat/redesign-ux-ui"}
```

