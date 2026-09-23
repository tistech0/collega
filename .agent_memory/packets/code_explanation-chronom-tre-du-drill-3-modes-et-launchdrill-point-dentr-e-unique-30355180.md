---
type: "Code Explanation"
title: "Chronomètre du drill : 3 modes et launchDrill point d'entrée unique"
description: "Story 8.4 : le chrono est une préférence TimerMode {off, on, ask} clé revision prefs timer mode, migration de l'ancien booléen . Tout lancement de drill Aujourd'hui, détail collège, détail d'item, recherche passe par lau"
resource: "collega_app/lib/features/drill/drill_launcher.dart"
tags: ["session-learning", "audit-2026-09-23"]
timestamp: "2026-09-23T15:53:29.258Z"
x-kage-id: "repo:git-github-com-tistech0-collega:code_explanation:chronom-tre-du-drill-3-modes-et-launchdrill-point-dentr-e-unique-1790178809259"
x-kage-type: "code_explanation"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_app/lib/features/drill/drill_launcher.dart", "collega_app/lib/features/drill/presentation/drill_timer_slot.dart", "collega_app/lib/features/profile/domain/revision_prefs.dart"]
---

# Chronomètre du drill : 3 modes et launchDrill point d'entrée unique

> Story 8.4 : le chrono est une préférence TimerMode {off, on, ask} clé revision prefs timer mode, migration de l'ancie…

Story 8.4 : le chrono est une préférence TimerMode {off, on, ask} (clé revision_prefs_timer_mode, migration de l'ancien booléen). Tout lancement de drill (Aujourd'hui, détail collège, détail d'item, recherche) passe par launchDrill (drill_launcher.dart) : en mode ask une sheet demande avec/sans chrono (fermer = annuler), verrou _launching anti double tap libéré post-frame. La préparation _launch renvoie un record ({Future<void> closed})? car une fonction async qui renvoie un Future l'attendrait (le verrou resterait posé tout le drill) ; launchDrill (Future<void>) libère le verrou une frame après l'ouverture puis attend closed. Pendant le drill, DrillTimerSlot : tap = activer/couper, appui long = pause ; le chrono est suspendu pendant « Quitter ? ».
Verified by: flutter test test/features/drill test/features/profile ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)

## Verification

flutter test test/features/drill test/features/profile ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)

# Citations

[1] explicit_capture (2026-09-23T15:53:29.258Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:code_explanation:chronom-tre-du-drill-3-modes-et-launchdrill-point-dentr-e-unique-1790178809259","title":"Chronomètre du drill : 3 modes et launchDrill point d'entrée unique","summary":"Story 8.4 : le chrono est une préférence TimerMode {off, on, ask} clé revision prefs timer mode, migration de l'ancien booléen . Tout lancement de drill Aujourd'hui, détail collège, détail d'item, recherche passe par lau","body":"Story 8.4 : le chrono est une préférence TimerMode {off, on, ask} (clé revision_prefs_timer_mode, migration de l'ancien booléen). Tout lancement de drill (Aujourd'hui, détail collège, détail d'item, recherche) passe par launchDrill (drill_launcher.dart) : en mode ask une sheet demande avec/sans chrono (fermer = annuler), verrou _launching anti double tap libéré post-frame. La préparation _launch renvoie un record ({Future<void> closed})? car une fonction async qui renvoie un Future l'attendrait (le verrou resterait posé tout le drill) ; launchDrill (Future<void>) libère le verrou une frame après l'ouverture puis attend closed. Pendant le drill, DrillTimerSlot : tap = activer/couper, appui long = pause ; le chrono est suspendu pendant « Quitter ? ».\nVerified by: flutter test test/features/drill test/features/profile ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)","type":"code_explanation","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","audit-2026-09-23"],"paths":["collega_app/lib/features/drill/drill_launcher.dart","collega_app/lib/features/drill/presentation/drill_timer_slot.dart","collega_app/lib/features/profile/domain/revision_prefs.dart"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-23T15:53:29.258Z"}],"context":{"fact":"Story 8.4 : le chrono est une préférence TimerMode {off, on, ask} (clé revision_prefs_timer_mode, migration de l'ancien booléen). Tout lancement de drill (Aujourd'hui, détail collège, détail d'item, recherche) passe par launchDrill (drill_launcher.dart) : en mode ask une sheet demande avec/sans chrono (fermer = annuler), verrou _launching anti double tap libéré post-frame. La préparation _launch renvoie un record ({Future<void> closed})? car une fonction async qui renvoie un Future l'attendrait (le verrou resterait posé tout le drill) ; launchDrill (Future<void>) libère le verrou une frame après l'ouverture puis attend closed. Pendant le drill, DrillTimerSlot : tap = activer/couper, appui long = pause ; le chrono est suspendu pendant « Quitter ? ».\nVerified by: flutter test test/features/drill test/features/profile ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)","verification":"flutter test test/features/drill test/features/profile ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)"},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T15:53:29.258Z","path_fingerprints":[{"path":"collega_app/lib/features/drill/drill_launcher.dart","sha256":"11e49178cfdef00e75138bd964249aa7cf7a6a0e41586b4851559e0d81086d5b","size":4063},{"path":"collega_app/lib/features/drill/presentation/drill_timer_slot.dart","sha256":"1e20292c4a5ed839cd74c499f40aa096ed4cbdd28bf8e9c102896caf510999d6","size":5386},{"path":"collega_app/lib/features/profile/domain/revision_prefs.dart","sha256":"8e944bd0875121aa6884ae7110dcf1f0cfa61c684e6581c9ef7290da58fc9cd2","size":1219}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[{"relation":"supersedes","to":"repo:git-github-com-tistech0-collega:code_explanation:chronom-tre-du-drill-3-modes-et-launchdrill-point-dentr-e-unique-1790112463856","evidence":"Revérifié contre main 560e503 (audit 2026-09-23) : passages périmés corrigés","created_at":"2026-09-23T15:53:29.603Z"}],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":2000,"discovery_tokens_estimated":true,"score":86,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":["possible duplicate memory"],"duplicate_candidates":[{"id":"repo:git-github-com-tistech0-collega:code_explanation:chronom-tre-du-drill-3-modes-et-launchdrill-point-dentr-e-unique-1790112463856","title":"Chronomètre du drill : 3 modes et launchDrill point d'entrée unique","score":0.7,"status":"approved"}],"estimated_tokens_saved":228},"created_at":"2026-09-23T15:53:29.258Z","updated_at":"2026-09-23T15:53:29.603Z","author_branch":"main"}
```

