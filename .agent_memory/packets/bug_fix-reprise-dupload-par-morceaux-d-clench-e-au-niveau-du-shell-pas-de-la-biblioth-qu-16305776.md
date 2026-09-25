---
type: "Bug Fix"
title: "Reprise d'upload par morceaux déclenchée au niveau du shell, pas de la Bibliothèque"
description: "Le ShellRoute de l'app n'est pas stateful : seul l'écran de l'onglet actif est monté. La reprise d'un upload par morceaux interrompu resumePendingUpload, Story 7.11 était déclenchée par CollegesScreen, donc ne tournait q"
resource: "collega_app/lib/features/colleges/presentation/pending_upload_resumer.dart"
tags: ["session-learning", "upload", "chunked", "resume", "story-7.11"]
timestamp: "2026-09-25T08:20:58.997Z"
x-kage-id: "repo:git-github-com-tistech0-collega:bug_fix:reprise-dupload-par-morceaux-d-clench-e-au-niveau-du-shell-pas-de-la-biblioth-qu"
x-kage-type: "bug_fix"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_app/lib/features/colleges/presentation/pending_upload_resumer.dart", "collega_app/lib/core/router/app_router.dart", "collega_app/lib/features/colleges/presentation/colleges_screen.dart", "collega_app/lib/features/colleges/domain/import_messages.dart"]
---

# Reprise d'upload par morceaux déclenchée au niveau du shell, pas de la Bibliothèque

> Le ShellRoute de l'app n'est pas stateful : seul l'écran de l'onglet actif est monté. La reprise d'un upload par morc…

Le ShellRoute de l'app n'est pas stateful : seul l'écran de l'onglet actif est monté. La reprise d'un upload par morceaux interrompu (resumePendingUpload, Story 7.11) était déclenchée par CollegesScreen, donc ne tournait que si l'utilisatrice ouvrait la Bibliothèque : après avoir tué l'app pendant un envoi, rien ne reprenait depuis Aujourd'hui et l'import d'un autre collège restait bloqué (« un autre PDF est en cours d'envoi ») sans explication. Correctif : PendingUploadResumer enveloppe AppShell dans app_router.dart (démarrage + retour premier plan, tout onglet). Le message de blocage nomme désormais le collège (uploadInProgressMessage). Une seule grosse PDF à la fois côté app (pending_uploads), mais le serveur accepte des générations parallèles de collèges différents.
Evidence: Logs prod 2026-09-25 : upload c31109a8 (ref 3) ouvert 08:03, complete 08:15 ; tests flutter colleges/shell/core verts

## Verification

Logs prod 2026-09-25 : upload c31109a8 (ref 3) ouvert 08:03, complete 08:15 ; tests flutter colleges/shell/core verts

# Citations

[1] explicit_capture (2026-09-25T08:20:58.997Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:bug_fix:reprise-dupload-par-morceaux-d-clench-e-au-niveau-du-shell-pas-de-la-biblioth-qu","title":"Reprise d'upload par morceaux déclenchée au niveau du shell, pas de la Bibliothèque","summary":"Le ShellRoute de l'app n'est pas stateful : seul l'écran de l'onglet actif est monté. La reprise d'un upload par morceaux interrompu resumePendingUpload, Story 7.11 était déclenchée par CollegesScreen, donc ne tournait q","body":"Le ShellRoute de l'app n'est pas stateful : seul l'écran de l'onglet actif est monté. La reprise d'un upload par morceaux interrompu (resumePendingUpload, Story 7.11) était déclenchée par CollegesScreen, donc ne tournait que si l'utilisatrice ouvrait la Bibliothèque : après avoir tué l'app pendant un envoi, rien ne reprenait depuis Aujourd'hui et l'import d'un autre collège restait bloqué (« un autre PDF est en cours d'envoi ») sans explication. Correctif : PendingUploadResumer enveloppe AppShell dans app_router.dart (démarrage + retour premier plan, tout onglet). Le message de blocage nomme désormais le collège (uploadInProgressMessage). Une seule grosse PDF à la fois côté app (pending_uploads), mais le serveur accepte des générations parallèles de collèges différents.\nEvidence: Logs prod 2026-09-25 : upload c31109a8 (ref 3) ouvert 08:03, complete 08:15 ; tests flutter colleges/shell/core verts","type":"bug_fix","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","upload","chunked","resume","story-7.11"],"paths":["collega_app/lib/features/colleges/presentation/pending_upload_resumer.dart","collega_app/lib/core/router/app_router.dart","collega_app/lib/features/colleges/presentation/colleges_screen.dart","collega_app/lib/features/colleges/domain/import_messages.dart"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-25T08:20:58.997Z"}],"context":{"fact":"Le ShellRoute de l'app n'est pas stateful : seul l'écran de l'onglet actif est monté. La reprise d'un upload par morceaux interrompu (resumePendingUpload, Story 7.11) était déclenchée par CollegesScreen, donc ne tournait que si l'utilisatrice ouvrait la Bibliothèque : après avoir tué l'app pendant un envoi, rien ne reprenait depuis Aujourd'hui et l'import d'un autre collège restait bloqué (« un autre PDF est en cours d'envoi ») sans explication. Correctif : PendingUploadResumer enveloppe AppShell dans app_router.dart (démarrage + retour premier plan, tout onglet). Le message de blocage nomme désormais le collège (uploadInProgressMessage). Une seule grosse PDF à la fois côté app (pending_uploads), mais le serveur accepte des générations parallèles de collèges différents.\nEvidence: Logs prod 2026-09-25 : upload c31109a8 (ref 3) ouvert 08:03, complete 08:15 ; tests flutter colleges/shell/core verts","verification":"Logs prod 2026-09-25 : upload c31109a8 (ref 3) ouvert 08:03, complete 08:15 ; tests flutter colleges/shell/core verts"},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-25T08:20:58.997Z","path_fingerprints":[{"path":"collega_app/lib/features/colleges/presentation/pending_upload_resumer.dart","sha256":"d9aa48ba1878d37120e173a9014e1f88bb7cf4e5d61b113b64ae0591c0d227a8","size":1256},{"path":"collega_app/lib/core/router/app_router.dart","sha256":"9531f32d060dda6e31603494236d6a931a9963c864be050f321609e7641b14aa","size":9454},{"path":"collega_app/lib/features/colleges/presentation/colleges_screen.dart","sha256":"675a400ce579d9eb2c4a7be7125256beeb91bed3904146b3cc6ac76049f7bb32","size":11416},{"path":"collega_app/lib/features/colleges/domain/import_messages.dart","sha256":"dfbb1359aac8cf646b150cbf77a65954e9408d97c747902020428a2f11ea5063","size":2634}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":8000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"stale_reasons":[],"estimated_tokens_saved":227},"created_at":"2026-09-25T08:20:58.997Z","updated_at":"2026-09-25T08:20:58.997Z","author_branch":"feat/refonte-back-infra"}
```

