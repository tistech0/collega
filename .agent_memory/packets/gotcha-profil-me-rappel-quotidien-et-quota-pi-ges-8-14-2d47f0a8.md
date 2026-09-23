---
type: "Gotcha"
title: "Profil : /me, rappel quotidien et quota — pièges (8.14)"
description: "Before 8.14, refreshFromMe was never called, so the profile and quota shown were frozen at login time. The Profile screen now calls AuthNotifier.refreshProfile when it opens and on pull to refresh. Account safety rules:"
resource: "collega_app/lib/features/auth/auth_providers.dart"
tags: ["session-learning", "profil", "auth", "rappel", "story-8.14", "audit-2026-09-23"]
timestamp: "2026-09-23T15:53:43.706Z"
x-kage-id: "repo:git-github-com-tistech0-collega:gotcha:profil-me-rappel-quotidien-et-quota-pi-ges-8-14-1790178823706"
x-kage-type: "gotcha"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_app/lib/features/auth/auth_providers.dart", "collega_app/lib/features/auth/data/auth_repository.dart", "collega_app/lib/features/profile/presentation/profile_screen.dart", "collega_app/lib/features/profile/domain/reminder_sync.dart", "collega_app/lib/core/notifications/notifications_service.dart", "collega_backend/app/api/v1/auth.py"]
---

# Profil : /me, rappel quotidien et quota — pièges (8.14)

> Before 8.14, refreshFromMe was never called, so the profile and quota shown were frozen at login time. The Profile sc…

Before 8.14, refreshFromMe was never called, so the profile and quota shown were frozen at login time. The Profile screen now calls AuthNotifier.refreshProfile when it opens and on pull-to-refresh.

Account-safety rules:
- refreshFromMe writes nothing if the id returned by /me differs from the stored user_id; that covers a late answer arriving after logout or a switch to another account.
- refreshProfile ignores a result that started before a local write, tracked by the _localWrites counter.

Backend: /me returns the current month's reimport quota (0 once monthly_reloads_reset_at has passed), monthly_reloads_reset_at and reminder_hour_utc.

Daily reminder:
- The server stores a UTC hour. The app also keeps the local hour the user chose (storage key reminder_local_hour).
- app.dart calls resyncReminderOffset (and requestPermissionsAndRegister) in a ref.listen on authProvider, every time an authenticated state is emitted (startup included), to re-align the UTC hour after a daylight-saving change.
- NotificationsService.requestPermissionsAndRegister returns whether notifications are authorised; if denied, the reminder is not set.

Logout clears paywallProvider. A forced logout (401) also deletes reminder_hour_utc, reminder_local_hour and monthly_reset_at.
Evidence: Adversarial review of 8.14: late /me could write account A's data onto account B, and the reminder drifted one hour at each daylight-saving change. Both covered by tests in auth_repository_test, auth_providers_test, profile_screen_test and reminder_sync_test.
Verified by: flutter test test/features/auth (80) test/features/profile (48); pytest tests/api/test_auth.py; deployed image 5f92eb8 ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)

## Verification

Adversarial review of 8.14: late /me could write account A's data onto account B, and the reminder drifted one hour at each daylight-saving change. Both covered by tests in auth_repository_test, auth_providers_test, profile_screen_test and reminder_sync_test.

# Citations

[1] explicit_capture (2026-09-23T15:53:43.706Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:gotcha:profil-me-rappel-quotidien-et-quota-pi-ges-8-14-1790178823706","title":"Profil : /me, rappel quotidien et quota — pièges (8.14)","summary":"Before 8.14, refreshFromMe was never called, so the profile and quota shown were frozen at login time. The Profile screen now calls AuthNotifier.refreshProfile when it opens and on pull to refresh. Account safety rules:","body":"Before 8.14, refreshFromMe was never called, so the profile and quota shown were frozen at login time. The Profile screen now calls AuthNotifier.refreshProfile when it opens and on pull-to-refresh.\n\nAccount-safety rules:\n- refreshFromMe writes nothing if the id returned by /me differs from the stored user_id; that covers a late answer arriving after logout or a switch to another account.\n- refreshProfile ignores a result that started before a local write, tracked by the _localWrites counter.\n\nBackend: /me returns the current month's reimport quota (0 once monthly_reloads_reset_at has passed), monthly_reloads_reset_at and reminder_hour_utc.\n\nDaily reminder:\n- The server stores a UTC hour. The app also keeps the local hour the user chose (storage key reminder_local_hour).\n- app.dart calls resyncReminderOffset (and requestPermissionsAndRegister) in a ref.listen on authProvider, every time an authenticated state is emitted (startup included), to re-align the UTC hour after a daylight-saving change.\n- NotificationsService.requestPermissionsAndRegister returns whether notifications are authorised; if denied, the reminder is not set.\n\nLogout clears paywallProvider. A forced logout (401) also deletes reminder_hour_utc, reminder_local_hour and monthly_reset_at.\nEvidence: Adversarial review of 8.14: late /me could write account A's data onto account B, and the reminder drifted one hour at each daylight-saving change. Both covered by tests in auth_repository_test, auth_providers_test, profile_screen_test and reminder_sync_test.\nVerified by: flutter test test/features/auth (80) test/features/profile (48); pytest tests/api/test_auth.py; deployed image 5f92eb8 ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)","type":"gotcha","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","profil","auth","rappel","story-8.14","audit-2026-09-23"],"paths":["collega_app/lib/features/auth/auth_providers.dart","collega_app/lib/features/auth/data/auth_repository.dart","collega_app/lib/features/profile/presentation/profile_screen.dart","collega_app/lib/features/profile/domain/reminder_sync.dart","collega_app/lib/core/notifications/notifications_service.dart","collega_backend/app/api/v1/auth.py"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-23T15:53:43.706Z"}],"context":{"fact":"Before 8.14, refreshFromMe was never called, so the profile and quota shown were frozen at login time. The Profile screen now calls AuthNotifier.refreshProfile when it opens and on pull-to-refresh.","verification":"Adversarial review of 8.14: late /me could write account A's data onto account B, and the reminder drifted one hour at each daylight-saving change. Both covered by tests in auth_repository_test, auth_providers_test, profile_screen_test and reminder_sync_test."},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T15:53:43.706Z","path_fingerprints":[{"path":"collega_app/lib/features/auth/auth_providers.dart","sha256":"c724285d6dbade2ab6d57f2d3630005a1668dab2706c7835fe7716fc3daf7376","size":10877},{"path":"collega_app/lib/features/auth/data/auth_repository.dart","sha256":"cb11127f35bcd4d02e2a6cbaf450e6725e39b303fd95268b2d8fb22c2f3b01b1","size":16160},{"path":"collega_app/lib/features/profile/presentation/profile_screen.dart","sha256":"b767aa5ad9abf6d25a1a30834b371da88909d495826ecaebf7fa894e7a80cc1d","size":22428},{"path":"collega_app/lib/features/profile/domain/reminder_sync.dart","sha256":"ddd502de8926a418e1a7d5332ef6646cff56725d7a0453e541b4e82270961907","size":1101},{"path":"collega_app/lib/core/notifications/notifications_service.dart","sha256":"cf4dc9ef11cacea77f0ef0f033dfe51559de0959da26bdd6d75fb08b146d365e","size":3676},{"path":"collega_backend/app/api/v1/auth.py","sha256":"13c19d4ed3a63dcd4368f8e4cc959df76589c87c6823f426e9c82769e71bb275","size":6166}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[{"relation":"supersedes","to":"repo:git-github-com-tistech0-collega:gotcha:profil-me-rappel-quotidien-et-quota-pi-ges-8-14-1790160750557","evidence":"Revérifié contre main 560e503 (audit 2026-09-23) : passages périmés corrigés","created_at":"2026-09-23T15:53:44.043Z"}],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":8000,"discovery_tokens_estimated":true,"score":86,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":["possible duplicate memory"],"duplicate_candidates":[{"id":"repo:git-github-com-tistech0-collega:gotcha:profil-me-rappel-quotidien-et-quota-pi-ges-8-14-1790160750557","title":"Profil : /me, rappel quotidien et quota — pièges (8.14)","score":0.86,"status":"approved"}],"estimated_tokens_saved":440,"total_uses":0},"created_at":"2026-09-23T15:53:43.706Z","updated_at":"2026-09-23T15:53:44.043Z","author_branch":"main"}
```

