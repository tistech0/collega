---
type: "Convention"
title: "Shell : plus aucun écran legacy, chaque écran d'onglet réserve la tab bar lui-même"
description: "Since story 8.14, the Profile tab is built in Collega UI, so AppShell lib/features/shell/app shell.dart no longer has a legacy mode. The legacyPattern and the bottom padding it added are gone. Every tab screen must reser"
resource: "collega_app/lib/features/shell/app_shell.dart"
tags: ["session-learning", "shell", "tab-bar", "collega-ui", "audit-2026-09-23"]
timestamp: "2026-09-23T15:53:36.243Z"
x-kage-id: "repo:git-github-com-tistech0-collega:convention:shell-plus-aucun-cran-legacy-chaque-cran-donglet-r-serve-la-tab-bar-lui-m-me-179"
x-kage-type: "convention"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_app/lib/features/shell/app_shell.dart", "collega_app/lib/features/profile/presentation/profile_screen.dart", "collega_app/test/features/shell/app_shell_test.dart"]
---

# Shell : plus aucun écran legacy, chaque écran d'onglet réserve la tab bar lui-même

> Since story 8.14, the Profile tab is built in Collega UI, so AppShell lib/features/shell/app shell.dart no longer has…

Since story 8.14, the Profile tab is built in Collega UI, so AppShell (lib/features/shell/app_shell.dart) no longer has a legacy mode. The _legacyPattern and the bottom padding it added are gone. Every tab screen must reserve the floating tab bar itself with CgPage(reserveTabBar: true), and scroll back to the top when the active tab is re-tapped: use TabReselectScrollMixin (Colleges, Progress, Profile), or listen to TabReselectScope directly as TodayScreen does. College and item detail screens still render under the tab they were opened from (CollegeDetailOrigin: /colleges, /home/colleges, /progress/colleges).
Verified by: flutter test test/features/shell (11 green, /profile full height with safe area intact) ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)

## Verification

flutter test test/features/shell (11 green, /profile full height with safe area intact) ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)

# Citations

[1] explicit_capture (2026-09-23T15:53:36.243Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:convention:shell-plus-aucun-cran-legacy-chaque-cran-donglet-r-serve-la-tab-bar-lui-m-me-179","title":"Shell : plus aucun écran legacy, chaque écran d'onglet réserve la tab bar lui-même","summary":"Since story 8.14, the Profile tab is built in Collega UI, so AppShell lib/features/shell/app shell.dart no longer has a legacy mode. The legacyPattern and the bottom padding it added are gone. Every tab screen must reser","body":"Since story 8.14, the Profile tab is built in Collega UI, so AppShell (lib/features/shell/app_shell.dart) no longer has a legacy mode. The _legacyPattern and the bottom padding it added are gone. Every tab screen must reserve the floating tab bar itself with CgPage(reserveTabBar: true), and scroll back to the top when the active tab is re-tapped: use TabReselectScrollMixin (Colleges, Progress, Profile), or listen to TabReselectScope directly as TodayScreen does. College and item detail screens still render under the tab they were opened from (CollegeDetailOrigin: /colleges, /home/colleges, /progress/colleges).\nVerified by: flutter test test/features/shell (11 green, /profile full height with safe area intact) ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)","type":"convention","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","shell","tab-bar","collega-ui","audit-2026-09-23"],"paths":["collega_app/lib/features/shell/app_shell.dart","collega_app/lib/features/profile/presentation/profile_screen.dart","collega_app/test/features/shell/app_shell_test.dart"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-23T15:53:36.243Z"}],"context":{"fact":"Since story 8.14, the Profile tab is built in Collega UI, so AppShell (lib/features/shell/app_shell.dart) no longer has a legacy mode. The _legacyPattern and the bottom padding it added are gone. Every tab screen must reserve the floating tab bar itself with CgPage(reserveTabBar: true), and scroll back to the top when the active tab is re-tapped: use TabReselectScrollMixin (Colleges, Progress, Profile), or listen to TabReselectScope directly as TodayScreen does. College and item detail screens still render under the tab they were opened from (CollegeDetailOrigin: /colleges, /home/colleges, /progress/colleges).\nVerified by: flutter test test/features/shell (11 green, /profile full height with safe area intact) ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)","verification":"flutter test test/features/shell (11 green, /profile full height with safe area intact) ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)"},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T15:53:36.243Z","path_fingerprints":[{"path":"collega_app/lib/features/shell/app_shell.dart","sha256":"cad040a8437e8c1a1498cdd9e81fa10e61d667262ee506ed35a878c7ea0539b4","size":2258},{"path":"collega_app/lib/features/profile/presentation/profile_screen.dart","sha256":"b767aa5ad9abf6d25a1a30834b371da88909d495826ecaebf7fa894e7a80cc1d","size":22428},{"path":"collega_app/test/features/shell/app_shell_test.dart","sha256":"6851653fb40537279c594463b0df0f68f0964ef509a182bf8b2667eca67b2b40","size":4147}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":3,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":2000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":201,"total_uses":3,"last_accessed_at":"2026-09-24T18:17:27.375Z"},"created_at":"2026-09-23T15:53:36.243Z","updated_at":"2026-09-23T15:53:36.243Z","author_branch":"main"}
```

