---
type: "Gotcha"
title: "Un envoi par morceaux en cours n'existe pas encore côté serveur"
description: "During a chunked PDF upload, including one resumed after the app was closed, the server has no college row until the upload's final \"complete\" call returns 202. So collegesProvider still lists the college as catalog, and"
resource: "collega_app/lib/features/colleges/presentation/colleges_screen.dart"
tags: ["session-learning", "import", "chunked-upload", "bibliotheque"]
timestamp: "2026-09-23T10:19:20.115Z"
x-kage-id: "repo:git-github-com-tistech0-collega:gotcha:un-envoi-par-morceaux-en-cours-nexiste-pas-encore-c-t-serveur-1790158760115"
x-kage-type: "gotcha"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_app/lib/features/colleges/presentation/colleges_screen.dart", "collega_app/lib/features/colleges/colleges_import_providers.dart", "collega_app/lib/features/colleges/presentation/college_detail_screen.dart"]
---

# Un envoi par morceaux en cours n'existe pas encore côté serveur

> During a chunked PDF upload, including one resumed after the app was closed, the server has no college row until the …

During a chunked PDF upload, including one resumed after the app was closed, the server has no college row until the upload's final "complete" call returns 202. So collegesProvider still lists the college as catalog, and the UI used to show "Importer". The fix: colleges_screen.dart watches collegeImportProvider and moves an ImportUploading(refId) entry into "Mes collèges" with the subtitle "envoi N %, reprend tout seul" (tap opens /colleges/:ref/import). _afterUploadAccepted then invalidates collegesProvider, so the row becomes "import en cours". The college detail screen's in-progress state offers "Suivre l’import", which opens /colleges/:ref/import/progress.
Evidence: User on iPhone: closed the app mid-upload; on reopen the upload resumed (parts 1-8, complete 202) but the Library showed "Importer" until it finished. Covered by tests in colleges_screen_test, college_import_notifier_test and college_detail_screen_test.
Verified by: flutter test test/features/colleges (223 green)

## Verification

User on iPhone: closed the app mid-upload; on reopen the upload resumed (parts 1-8, complete 202) but the Library showed "Importer" until it finished. Covered by tests in colleges_screen_test, college_import_notifier_test and college_detail_screen_test.

# Citations

[1] explicit_capture (2026-09-23T10:19:20.115Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:gotcha:un-envoi-par-morceaux-en-cours-nexiste-pas-encore-c-t-serveur-1790158760115","title":"Un envoi par morceaux en cours n'existe pas encore côté serveur","summary":"During a chunked PDF upload, including one resumed after the app was closed, the server has no college row until the upload's final \"complete\" call returns 202. So collegesProvider still lists the college as catalog, and","body":"During a chunked PDF upload, including one resumed after the app was closed, the server has no college row until the upload's final \"complete\" call returns 202. So collegesProvider still lists the college as catalog, and the UI used to show \"Importer\". The fix: colleges_screen.dart watches collegeImportProvider and moves an ImportUploading(refId) entry into \"Mes collèges\" with the subtitle \"envoi N %, reprend tout seul\" (tap opens /colleges/:ref/import). _afterUploadAccepted then invalidates collegesProvider, so the row becomes \"import en cours\". The college detail screen's in-progress state offers \"Suivre l’import\", which opens /colleges/:ref/import/progress.\nEvidence: User on iPhone: closed the app mid-upload; on reopen the upload resumed (parts 1-8, complete 202) but the Library showed \"Importer\" until it finished. Covered by tests in colleges_screen_test, college_import_notifier_test and college_detail_screen_test.\nVerified by: flutter test test/features/colleges (223 green)","type":"gotcha","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","import","chunked-upload","bibliotheque"],"paths":["collega_app/lib/features/colleges/presentation/colleges_screen.dart","collega_app/lib/features/colleges/colleges_import_providers.dart","collega_app/lib/features/colleges/presentation/college_detail_screen.dart"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-23T10:19:20.115Z"}],"context":{"fact":"During a chunked PDF upload, including one resumed after the app was closed, the server has no college row until the upload's final \"complete\" call returns 202. So collegesProvider still lists the college as catalog, and the UI used to show \"Importer\". The fix: colleges_screen.dart watches collegeImportProvider and moves an ImportUploading(refId) entry into \"Mes collèges\" with the subtitle \"envoi N %, reprend tout seul\" (tap opens /colleges/:ref/import). _afterUploadAccepted then invalidates collegesProvider, so the row becomes \"import en cours\". The college detail screen's in-progress state offers \"Suivre l’import\", which opens /colleges/:ref/import/progress.\nEvidence: User on iPhone: closed the app mid-upload; on reopen the upload resumed (parts 1-8, complete 202) but the Library showed \"Importer\" until it finished. Covered by tests in colleges_screen_test, college_import_notifier_test and college_detail_screen_test.\nVerified by: flutter test test/features/colleges (223 green)","verification":"User on iPhone: closed the app mid-upload; on reopen the upload resumed (parts 1-8, complete 202) but the Library showed \"Importer\" until it finished. Covered by tests in colleges_screen_test, college_import_notifier_test and college_detail_screen_test."},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T10:19:20.115Z","path_fingerprints":[{"path":"collega_app/lib/features/colleges/presentation/colleges_screen.dart","sha256":"80a67a80bb23a278fba462a1a2c58248159ebf3288bbce56522db1cd1f611c41","size":11804},{"path":"collega_app/lib/features/colleges/colleges_import_providers.dart","sha256":"6d9b591a9906a550306b1c5ce2f0c2370fd9f60d0abb94e568ae602046d2845f","size":17318},{"path":"collega_app/lib/features/colleges/presentation/college_detail_screen.dart","sha256":"48befc24711c1f13873898714279084ada81ead2a41a5c32daeff330289dc39e","size":18079}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":8000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"stale_reasons":[],"estimated_tokens_saved":249},"created_at":"2026-09-23T10:19:20.115Z","updated_at":"2026-09-23T10:19:20.115Z","author_branch":"feat/redesign-ux-ui"}
```

