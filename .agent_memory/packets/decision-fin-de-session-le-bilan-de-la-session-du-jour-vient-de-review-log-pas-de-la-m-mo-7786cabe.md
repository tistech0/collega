---
type: "Decision"
title: "Fin de session : le bilan de la session du jour vient de review_log, pas de la mémoire"
description: "DrillEndScreen story 8.5 affiche le bilan d'une session du jour reprise : les évaluations sont reconstruites depuis DailySessionRepository.lastVerdicts day , sinon le score n'aurait que les fiches jugées après la reprise"
resource: "collega_app/lib/features/drill/presentation/drill_end_screen.dart"
tags: ["session-learning"]
timestamp: "2026-09-23T08:33:14.870Z"
x-kage-id: "repo:git-github-com-tistech0-collega:decision:fin-de-session-le-bilan-de-la-session-du-jour-vient-de-review-log-pas-de-la-m-mo"
x-kage-type: "decision"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "verified"
x-kage-paths: ["collega_app/lib/features/drill/presentation/drill_end_screen.dart", "collega_app/lib/features/drill/drill_providers.dart", "collega_app/lib/features/today/today_providers.dart", "collega_app/lib/features/today/data/daily_session_repository.dart"]
---

# Fin de session : le bilan de la session du jour vient de review_log, pas de la mémoire

> DrillEndScreen story 8.5 affiche le bilan d'une session du jour reprise : les évaluations sont reconstruites depuis D…

DrillEndScreen (story 8.5) affiche le bilan d'une session du jour reprise : les évaluations sont reconstruites depuis DailySessionRepository.lastVerdicts(day), sinon le score n'aurait que les fiches jugées après la reprise. « Refaire les à revoir » (replayingErrors) n'écrit jamais dans review_log (garde !_replayingErrors dans DrillNotifier), pour que le bilan du jour reste celui de la vraie session. Le budget « Demain · N fiches » vient de TodayReady.tomorrowBudget (le réglage), pas de la taille de la session du jour. Les titres d'items sont facultatifs (catchError) : hors-ligne ne bloque pas la fin. total == 0 (fiches disparues après réimport) → état « Aucune fiche à réviser », sans score ni haptique.
Verified by: flutter test test/features/drill test/features/today (231 verts)

## Verification

flutter test test/features/drill test/features/today (231 verts)

# Citations

[1] explicit_capture (2026-09-22T21:27:40.299Z)
[2] reverification
[3] reverification
[4] reverification

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:decision:fin-de-session-le-bilan-de-la-session-du-jour-vient-de-review-log-pas-de-la-m-mo","title":"Fin de session : le bilan de la session du jour vient de review_log, pas de la mémoire","summary":"DrillEndScreen story 8.5 affiche le bilan d'une session du jour reprise : les évaluations sont reconstruites depuis DailySessionRepository.lastVerdicts day , sinon le score n'aurait que les fiches jugées après la reprise","body":"DrillEndScreen (story 8.5) affiche le bilan d'une session du jour reprise : les évaluations sont reconstruites depuis DailySessionRepository.lastVerdicts(day), sinon le score n'aurait que les fiches jugées après la reprise. « Refaire les à revoir » (replayingErrors) n'écrit jamais dans review_log (garde !_replayingErrors dans DrillNotifier), pour que le bilan du jour reste celui de la vraie session. Le budget « Demain · N fiches » vient de TodayReady.tomorrowBudget (le réglage), pas de la taille de la session du jour. Les titres d'items sont facultatifs (catchError) : hors-ligne ne bloque pas la fin. total == 0 (fiches disparues après réimport) → état « Aucune fiche à réviser », sans score ni haptique.\nVerified by: flutter test test/features/drill test/features/today (231 verts)","type":"decision","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning"],"paths":["collega_app/lib/features/drill/presentation/drill_end_screen.dart","collega_app/lib/features/drill/drill_providers.dart","collega_app/lib/features/today/today_providers.dart","collega_app/lib/features/today/data/daily_session_repository.dart"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-22T21:27:40.299Z"},{"kind":"reverification","at":"2026-09-23T07:48:13.004Z","evidence":"stories 8.6-8.7 (4963b94) : comportement inchangé, flutter test colleges/today/drill verts","changed_paths":[{"path":"collega_app/lib/features/today/today_providers.dart","prior_sha256":"d42977d63e4be3d6bc83a22332cd8cabe86c9c8d45c05ee3b4c471c56fe5713f","sha256":"b0ee166a70cc2f7ba5b91544a58911b25a9e709af535958fd6f499998b226354"}]},{"kind":"reverification","at":"2026-09-23T08:27:30.435Z","evidence":"stories 8.8-8.9 (1cb63e6) : comportement décrit inchangé ; tests planning/progress/today/drill/colleges verts","changed_paths":[{"path":"collega_app/lib/features/drill/drill_providers.dart","prior_sha256":"702ec50eab2297104cf16be5c9ac1294565c468c0fd93094ae96138689d78ac2","sha256":"6637644ec1e1c248a7e4eea6d057f2552ad58ff5d61e8f8220dc80488668415b"},{"path":"collega_app/lib/features/today/today_providers.dart","prior_sha256":"b0ee166a70cc2f7ba5b91544a58911b25a9e709af535958fd6f499998b226354","sha256":"5ed881978c33b31ae769b956112c392f563a3eb3d2f00c5900e65766537807b3"},{"path":"collega_app/lib/features/today/data/daily_session_repository.dart","prior_sha256":"52dce060ce1c69ca013ae6167a73c14e00a0684f717e104c36367fdd8d6bceee","sha256":"bb7d3065c49f132f1badc1f7bdb2b25aae97d45f113f42ed5a2e6b0c5e3f6315"}]},{"kind":"reverification","at":"2026-09-23T08:33:14.870Z","evidence":"8de2c21 : ajout outil de test (kTestTools, resetDay) sans changer le comportement décrit","changed_paths":[{"path":"collega_app/lib/features/today/data/daily_session_repository.dart","prior_sha256":"bb7d3065c49f132f1badc1f7bdb2b25aae97d45f113f42ed5a2e6b0c5e3f6315","sha256":"152d7e080a7f93258d4ae527b713c6c884947051abd64833e917f5f900be6d9d"}]}],"context":{"fact":"DrillEndScreen (story 8.5) affiche le bilan d'une session du jour reprise : les évaluations sont reconstruites depuis DailySessionRepository.lastVerdicts(day), sinon le score n'aurait que les fiches jugées après la reprise. « Refaire les à revoir » (replayingErrors) n'écrit jamais dans review_log (garde !_replayingErrors dans DrillNotifier), pour que le bilan du jour reste celui de la vraie session. Le budget « Demain · N fiches » vient de TodayReady.tomorrowBudget (le réglage), pas de la taille de la session du jour. Les titres d'items sont facultatifs (catchError) : hors-ligne ne bloque pas la fin. total == 0 (fiches disparues après réimport) → état « Aucune fiche à réviser », sans score ni haptique.\nVerified by: flutter test test/features/drill test/features/today (231 verts)","verification":"flutter test test/features/drill test/features/today (231 verts)"},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T08:33:14.870Z","path_fingerprints":[{"path":"collega_app/lib/features/drill/presentation/drill_end_screen.dart","sha256":"94245977b7c4b6aec75346769ef2c293a81f3f1d05ffc5f81e000862fc8222d3","size":12819},{"path":"collega_app/lib/features/drill/drill_providers.dart","sha256":"6637644ec1e1c248a7e4eea6d057f2552ad58ff5d61e8f8220dc80488668415b","size":9775},{"path":"collega_app/lib/features/today/today_providers.dart","sha256":"5ed881978c33b31ae769b956112c392f563a3eb3d2f00c5900e65766537807b3","size":11718},{"path":"collega_app/lib/features/today/data/daily_session_repository.dart","sha256":"152d7e080a7f93258d4ae527b713c6c884947051abd64833e917f5f900be6d9d","size":10857}],"path_fingerprint_policy":"source_hash_staleness","verification":"evidence_reverification"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":4000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":198,"reverified_at":"2026-09-23T08:33:14.870Z"},"created_at":"2026-09-22T21:27:40.299Z","updated_at":"2026-09-23T08:33:14.870Z","author_branch":"feat/redesign-ux-ui"}
```

