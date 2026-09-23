---
type: "Gotcha"
title: "Tests Flutter : lancer par dossier ciblé ; les tests home ont disparu en 8.3"
description: "Les tests test/features/home home notifier, home screen ont été supprimés avec l'écran Home en story 8.3 remplacé par Aujourd'hui, test/features/today . Convention du projet : ne jamais lancer flutter test global, toujou"
resource: "collega_app/test/features/today/today_provider_test.dart"
tags: ["session-learning"]
timestamp: "2026-09-23T15:40:03.927Z"
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
[3] reverification
[4] reverification
[5] reverification
[6] reverification
[7] reverification

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:gotcha:tests-flutter-lancer-par-dossier-cibl-les-tests-home-ont-disparu-en-8-3-17901124","title":"Tests Flutter : lancer par dossier ciblé ; les tests home ont disparu en 8.3","summary":"Les tests test/features/home home notifier, home screen ont été supprimés avec l'écran Home en story 8.3 remplacé par Aujourd'hui, test/features/today . Convention du projet : ne jamais lancer flutter test global, toujou","body":"Les tests test/features/home (home_notifier, home_screen) ont été supprimés avec l'écran Home en story 8.3 (remplacé par Aujourd'hui, test/features/today). Convention du projet : ne jamais lancer `flutter test` global, toujours par dossiers ciblés (ex. `flutter test test/features/drill test/features/today`, puis colleges/search/profile/core, puis shell/planning/demo/auth/generation). Il n'existe pas de dossier test/features/item_detail : le passer à flutter test compte comme un échec de chargement.\nVerified by: ls collega_app/test/features ; runs ciblés du 2026-09-22 (231 + 590 + 63 verts)","type":"gotcha","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning"],"paths":["collega_app/test/features/today/today_provider_test.dart","collega_app/test/features/profile/profile_screen_test.dart","collega_app/test/features/search/search_notifier_test.dart"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-22T21:28:11.178Z"},{"kind":"reverification","at":"2026-09-23T08:27:32.954Z","evidence":"stories 8.8-8.9 (1cb63e6) : comportement décrit inchangé ; tests planning/progress/today/drill/colleges verts","changed_paths":[{"path":"collega_app/test/features/today/today_provider_test.dart","prior_sha256":"a4331aa7132c2f631f1084988de9cc3a9f42628620f74b9f23bcfd41becb4b20","sha256":"edc31b96c19128969e40dcdc67afc2d493c7a77f5c27d101186fa5ff2e84f4af"}]},{"kind":"reverification","at":"2026-09-23T09:15:49.759Z","evidence":"stories 8.10-8.11 (5ed9392, b948dc4) : comportement décrit inchangé ; tests par dossier verts","changed_paths":[{"path":"collega_app/test/features/search/search_notifier_test.dart","prior_sha256":"19abcdd8fd5884959d9745aac3a5de78f20abb4189cc86fc34fb5893e5b97d1e","sha256":"2d4c79c69a96c07f33028f57cfe06e0e513ce3a94b91e7f3e8227eab1d1d398a"}]},{"kind":"reverification","at":"2026-09-23T10:43:28.807Z","evidence":"profile_screen_test réécrit en 8.14 (Collega UI) ; convention par dossiers inchangée ; nouveau dossier test/features/legal ; profile 43, auth 73, legal 12, shell 11 verts","changed_paths":[{"path":"collega_app/test/features/profile/profile_screen_test.dart","prior_sha256":"01eea89b3878a8578643233f5129978d6c74059389ef7d215d65d7884bc82101","sha256":"0f503b97af88dc584ad78eba9cd16ecf947bb6a15a2d65b494d96d20a8ff0e88"}]},{"kind":"reverification","at":"2026-09-23T10:52:40.275Z","evidence":"profile_screen_test étendu (48) ; convention par dossiers inchangée","changed_paths":[{"path":"collega_app/test/features/profile/profile_screen_test.dart","prior_sha256":"0f503b97af88dc584ad78eba9cd16ecf947bb6a15a2d65b494d96d20a8ff0e88","sha256":"e4eeab204c1da4beff5eba2fcee44c4f356299f86e16dc383de7f976f2f614b2"}]},{"kind":"reverification","at":"2026-09-23T12:08:43.507Z","evidence":"profile_screen_test : test d'accessibilité ajouté ; convention par dossiers inchangée ; profile 49 verts","changed_paths":[{"path":"collega_app/test/features/profile/profile_screen_test.dart","prior_sha256":"e4eeab204c1da4beff5eba2fcee44c4f356299f86e16dc383de7f976f2f614b2","sha256":"4637ce7286c0378807cdf847e1daeb06a7854b2363f1d7a859081de331d61604"}]},{"kind":"reverification","at":"2026-09-23T15:40:03.927Z","evidence":"profile_screen_test : attente du logo ajoutée ; convention par dossiers inchangée ; profile 49 verts","changed_paths":[{"path":"collega_app/test/features/profile/profile_screen_test.dart","prior_sha256":"4637ce7286c0378807cdf847e1daeb06a7854b2363f1d7a859081de331d61604","sha256":"6c8daf4c2a3f0a6b86103db1735afef9954a3bc618aab4d752b9305e139417ec"}]}],"context":{"fact":"Les tests test/features/home (home_notifier, home_screen) ont été supprimés avec l'écran Home en story 8.3 (remplacé par Aujourd'hui, test/features/today). Convention du projet : ne jamais lancer `flutter test` global, toujours par dossiers ciblés (ex. `flutter test test/features/drill test/features/today`, puis colleges/search/profile/core, puis shell/planning/demo/auth/generation). Il n'existe pas de dossier test/features/item_detail : le passer à flutter test compte comme un échec de chargement.\nVerified by: ls collega_app/test/features ; runs ciblés du 2026-09-22 (231 + 590 + 63 verts)","verification":"ls collega_app/test/features ; runs ciblés du 2026-09-22 (231 + 590 + 63 verts)"},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T15:40:03.927Z","path_fingerprints":[{"path":"collega_app/test/features/today/today_provider_test.dart","sha256":"edc31b96c19128969e40dcdc67afc2d493c7a77f5c27d101186fa5ff2e84f4af","size":11185},{"path":"collega_app/test/features/profile/profile_screen_test.dart","sha256":"6c8daf4c2a3f0a6b86103db1735afef9954a3bc618aab4d752b9305e139417ec","size":22633},{"path":"collega_app/test/features/search/search_notifier_test.dart","sha256":"2d4c79c69a96c07f33028f57cfe06e0e513ce3a94b91e7f3e8227eab1d1d398a","size":6603}],"path_fingerprint_policy":"source_hash_staleness","verification":"evidence_reverification"},"edges":[{"relation":"supersedes","to":"repo:git-github-com-tistech0-collega:gotcha:flutter-test-complet-pas-vert-home-notifier-binding-home-screen-timer-blocage-ap","evidence":"Tests home supprimés en 8.3 avec l'écran Home","created_at":"2026-09-22T21:28:19.215Z"}],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":8000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":149,"reverified_at":"2026-09-23T15:40:03.927Z"},"created_at":"2026-09-22T21:28:11.178Z","updated_at":"2026-09-23T15:40:03.927Z","author_branch":"feat/redesign-ux-ui"}
```

