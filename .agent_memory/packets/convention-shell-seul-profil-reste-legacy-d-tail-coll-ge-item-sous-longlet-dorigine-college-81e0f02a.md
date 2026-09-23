---
type: "Convention"
title: "Shell : seul Profil reste legacy ; détail collège/item sous l'onglet d'origine (CollegeDetailOrigin)"
description: "Depuis 8.11, AppShell. legacyPattern ne contient plus que /profile Scaffold jusqu'en 8.14 : tout écran migré en CgPage reserveTabBar: true doit en sortir, sinon la tab bar est réservée deux fois. Les détails collège et i"
resource: "collega_app/lib/features/shell/app_shell.dart"
tags: ["session-learning"]
timestamp: "2026-09-23T09:16:03.688Z"
x-kage-id: "repo:git-github-com-tistech0-collega:convention:shell-seul-profil-reste-legacy-d-tail-coll-ge-item-sous-longlet-dorigine-college"
x-kage-type: "convention"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_app/lib/features/shell/app_shell.dart", "collega_app/lib/core/router/app_router.dart", "collega_app/lib/features/colleges/presentation/college_detail_screen.dart", "collega_app/lib/features/search/presentation/search_sheet.dart"]
---

# Shell : seul Profil reste legacy ; détail collège/item sous l'onglet d'origine (CollegeDetailOrigin)

> Depuis 8.11, AppShell. legacyPattern ne contient plus que /profile Scaffold jusqu'en 8.14 : tout écran migré en CgPag…

Depuis 8.11, `AppShell._legacyPattern` ne contient plus que `/profile` (Scaffold jusqu'en 8.14) : tout écran migré en `CgPage(reserveTabBar: true)` doit en sortir, sinon la tab bar est réservée deux fois. Les détails collège et item existent sous trois bases (`CollegeDetailOrigin` : `/colleges`, `/home/colleges`, `/progress/colleges`) : onglet actif, libellé de retour et routes des items suivent l'origine ; la recherche reçoit l'origine (`showSearchSheet(context, origin:)`) et ouvre l'item sous la même base, extra `kFromSearch` → « ‹ Recherche ». « Hors connexion » seulement si `isNetworkUnreachable(e)`.
Verified by: test/features/shell/app_shell_test.dart + search_sheet_test (origine Aujourd'hui)

## Verification

test/features/shell/app_shell_test.dart + search_sheet_test (origine Aujourd'hui)

# Citations

[1] explicit_capture (2026-09-23T09:16:03.688Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:convention:shell-seul-profil-reste-legacy-d-tail-coll-ge-item-sous-longlet-dorigine-college","title":"Shell : seul Profil reste legacy ; détail collège/item sous l'onglet d'origine (CollegeDetailOrigin)","summary":"Depuis 8.11, AppShell. legacyPattern ne contient plus que /profile Scaffold jusqu'en 8.14 : tout écran migré en CgPage reserveTabBar: true doit en sortir, sinon la tab bar est réservée deux fois. Les détails collège et i","body":"Depuis 8.11, `AppShell._legacyPattern` ne contient plus que `/profile` (Scaffold jusqu'en 8.14) : tout écran migré en `CgPage(reserveTabBar: true)` doit en sortir, sinon la tab bar est réservée deux fois. Les détails collège et item existent sous trois bases (`CollegeDetailOrigin` : `/colleges`, `/home/colleges`, `/progress/colleges`) : onglet actif, libellé de retour et routes des items suivent l'origine ; la recherche reçoit l'origine (`showSearchSheet(context, origin:)`) et ouvre l'item sous la même base, extra `kFromSearch` → « ‹ Recherche ». « Hors connexion » seulement si `isNetworkUnreachable(e)`.\nVerified by: test/features/shell/app_shell_test.dart + search_sheet_test (origine Aujourd'hui)","type":"convention","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning"],"paths":["collega_app/lib/features/shell/app_shell.dart","collega_app/lib/core/router/app_router.dart","collega_app/lib/features/colleges/presentation/college_detail_screen.dart","collega_app/lib/features/search/presentation/search_sheet.dart"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-23T09:16:03.688Z"}],"context":{"fact":"Depuis 8.11, `AppShell._legacyPattern` ne contient plus que `/profile` (Scaffold jusqu'en 8.14) : tout écran migré en `CgPage(reserveTabBar: true)` doit en sortir, sinon la tab bar est réservée deux fois. Les détails collège et item existent sous trois bases (`CollegeDetailOrigin` : `/colleges`, `/home/colleges`, `/progress/colleges`) : onglet actif, libellé de retour et routes des items suivent l'origine ; la recherche reçoit l'origine (`showSearchSheet(context, origin:)`) et ouvre l'item sous la même base, extra `kFromSearch` → « ‹ Recherche ». « Hors connexion » seulement si `isNetworkUnreachable(e)`.\nVerified by: test/features/shell/app_shell_test.dart + search_sheet_test (origine Aujourd'hui)","verification":"test/features/shell/app_shell_test.dart + search_sheet_test (origine Aujourd'hui)"},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T09:16:03.688Z","path_fingerprints":[{"path":"collega_app/lib/features/shell/app_shell.dart","sha256":"ecaa8aa3805b09bbdb5f686d9c6d202fd9a72d3e4689bd8ad2944cfd954ab353","size":2952},{"path":"collega_app/lib/core/router/app_router.dart","sha256":"200c886187cf79fccfc6635ce6c0c52f949ca93317f9e8bca0e5fa785c917b18","size":6947},{"path":"collega_app/lib/features/colleges/presentation/college_detail_screen.dart","sha256":"d6d3a2d7ab6438301f43b75d26794e517cca31ebcd738942c763e055b1c3a786","size":17580},{"path":"collega_app/lib/features/search/presentation/search_sheet.dart","sha256":"6648cbcb33034c1310435c664726b09b3fffdc26a1cc9a570ac5e6b72516d0bf","size":11622}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[{"relation":"supersedes","to":"repo:git-github-com-tistech0-collega:convention:shell-crans-legacy-vs-collega-ui-routes-home-colleges-pour-le-d-tail-ouvert-depu","evidence":"Newer repo memory supersedes this packet.","created_at":"2026-09-23T09:16:09.298Z"}],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":2000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"stale_reasons":[],"estimated_tokens_saved":177},"created_at":"2026-09-23T09:16:03.688Z","updated_at":"2026-09-23T09:16:09.298Z","author_branch":"feat/redesign-ux-ui"}
```

