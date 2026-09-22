---
type: "Bug Fix"
title: "Progression collège : les fiches locales sont désormais TOUTES synchronisées (8.3) — la cause « items ouverts seulement » a disparu"
description: "Avant la story 8.3, les fiches n'arrivaient dans Drift qu'à l'ouverture d'un item ItemDetailNotifier → syncCardsToDrift , d'où une progression collège fausse « 0 % · 0 fiches » alors que la barre semblait pleine et Drill"
resource: "collega_app/lib/features/colleges/domain/drill_stats.dart"
tags: ["session-learning", "story-8.3", "progression", "sync", "drift"]
timestamp: "2026-09-22T19:32:02.919Z"
x-kage-id: "repo:git-github-com-tistech0-collega:bug_fix:progression-coll-ge-les-fiches-locales-sont-d-sormais-toutes-synchronis-es-8-3-l"
x-kage-type: "bug_fix"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_app/lib/features/colleges/domain/drill_stats.dart", "collega_app/lib/features/colleges/data/college_cards_sync.dart", "collega_app/lib/features/today/today_providers.dart", "collega_app/lib/features/colleges/presentation/college_detail_screen.dart"]
---

# Progression collège : les fiches locales sont désormais TOUTES synchronisées (8.3) — la cause « items ouverts seulement » a disparu

> Avant la story 8.3, les fiches n'arrivaient dans Drift qu'à l'ouverture d'un item ItemDetailNotifier → syncCardsToDri…

Avant la story 8.3, les fiches n'arrivaient dans Drift qu'à l'ouverture d'un item (ItemDetailNotifier → syncCardsToDrift), d'où une progression collège fausse (« 0 % · 0 fiches » alors que la barre semblait pleine) et DrillStats.withTotal(serverTotal) pour recaler les non vues. Depuis 8.3, Aujourd'hui synchronise toutes les fiches de chaque collège prêt via GET /v1/colleges/{id}/cards (syncCollegeCards, sans écraser drillLevel/nextReviewAt/reviewCount) : le décompte local est complet dès la première ouverture de l'app en ligne. withTotal reste utile tant que la synchro n'a pas eu lieu (premier lancement hors-ligne). Le détail collège (college_detail_screen.dart) sera réécrit en 8.7 sur ces données.
Evidence: test/features/today/today_provider_test.dart « collèges prêts : synchronise toutes leurs fiches » ; prod : 177 + 164 fiches renvoyées par l'endpoint.

## Verification

test/features/today/today_provider_test.dart « collèges prêts : synchronise toutes leurs fiches » ; prod : 177 + 164 fiches renvoyées par l'endpoint.

# Citations

[1] explicit_capture (2026-09-22T19:32:02.919Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:bug_fix:progression-coll-ge-les-fiches-locales-sont-d-sormais-toutes-synchronis-es-8-3-l","title":"Progression collège : les fiches locales sont désormais TOUTES synchronisées (8.3) — la cause « items ouverts seulement » a disparu","summary":"Avant la story 8.3, les fiches n'arrivaient dans Drift qu'à l'ouverture d'un item ItemDetailNotifier → syncCardsToDrift , d'où une progression collège fausse « 0 % · 0 fiches » alors que la barre semblait pleine et Drill","body":"Avant la story 8.3, les fiches n'arrivaient dans Drift qu'à l'ouverture d'un item (ItemDetailNotifier → syncCardsToDrift), d'où une progression collège fausse (« 0 % · 0 fiches » alors que la barre semblait pleine) et DrillStats.withTotal(serverTotal) pour recaler les non vues. Depuis 8.3, Aujourd'hui synchronise toutes les fiches de chaque collège prêt via GET /v1/colleges/{id}/cards (syncCollegeCards, sans écraser drillLevel/nextReviewAt/reviewCount) : le décompte local est complet dès la première ouverture de l'app en ligne. withTotal reste utile tant que la synchro n'a pas eu lieu (premier lancement hors-ligne). Le détail collège (college_detail_screen.dart) sera réécrit en 8.7 sur ces données.\nEvidence: test/features/today/today_provider_test.dart « collèges prêts : synchronise toutes leurs fiches » ; prod : 177 + 164 fiches renvoyées par l'endpoint.","type":"bug_fix","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","story-8.3","progression","sync","drift"],"paths":["collega_app/lib/features/colleges/domain/drill_stats.dart","collega_app/lib/features/colleges/data/college_cards_sync.dart","collega_app/lib/features/today/today_providers.dart","collega_app/lib/features/colleges/presentation/college_detail_screen.dart"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-22T19:32:02.919Z"}],"context":{"fact":"Avant la story 8.3, les fiches n'arrivaient dans Drift qu'à l'ouverture d'un item (ItemDetailNotifier → syncCardsToDrift), d'où une progression collège fausse (« 0 % · 0 fiches » alors que la barre semblait pleine) et DrillStats.withTotal(serverTotal) pour recaler les non vues. Depuis 8.3, Aujourd'hui synchronise toutes les fiches de chaque collège prêt via GET /v1/colleges/{id}/cards (syncCollegeCards, sans écraser drillLevel/nextReviewAt/reviewCount) : le décompte local est complet dès la première ouverture de l'app en ligne. withTotal reste utile tant que la synchro n'a pas eu lieu (premier lancement hors-ligne). Le détail collège (college_detail_screen.dart) sera réécrit en 8.7 sur ces données.\nEvidence: test/features/today/today_provider_test.dart « collèges prêts : synchronise toutes leurs fiches » ; prod : 177 + 164 fiches renvoyées par l'endpoint.","verification":"test/features/today/today_provider_test.dart « collèges prêts : synchronise toutes leurs fiches » ; prod : 177 + 164 fiches renvoyées par l'endpoint."},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-22T19:32:02.919Z","path_fingerprints":[{"path":"collega_app/lib/features/colleges/domain/drill_stats.dart","sha256":"181c49f17fae6c712923bc0631b25599937d8f5827832796c2e7b75af65ebe12","size":2086},{"path":"collega_app/lib/features/colleges/data/college_cards_sync.dart","sha256":"4206efc64a823f4ed419911bf532388cf4530cd01d39b140f94fe2ac34bbfe12","size":1802},{"path":"collega_app/lib/features/today/today_providers.dart","sha256":"1763b9d25f5e7d6bc23c44e6ed90b38cdc13858951549e763f341fdc26bfbcb7","size":11275},{"path":"collega_app/lib/features/colleges/presentation/college_detail_screen.dart","sha256":"c5f478b9ce57b4476e522ccbc94de54f0213e483856aad67de7d65095bc4481e","size":16194}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[{"relation":"supersedes","to":"repo:git-github-com-tistech0-collega:bug_fix:progression-coll-ge-0-0-fiches-vs-barre-pleine-fiches-locales-items-ouverts-seul","evidence":"La story 8.3 synchronise toutes les fiches : la cause « items ouverts seulement » n'existe plus","created_at":"2026-09-22T19:32:06.926Z"}],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":8000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"stale_reasons":[],"estimated_tokens_saved":217},"created_at":"2026-09-22T19:32:02.919Z","updated_at":"2026-09-22T19:32:06.926Z","author_branch":"feat/redesign-ux-ui"}
```

