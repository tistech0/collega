---
type: "Convention"
title: "Shell : écrans legacy vs Collega UI, routes /home/colleges pour le détail ouvert depuis Aujourd'hui"
description: "AppShell. legacyPattern liste les écrans du shell encore en Scaffold Material Profil jusqu'en 8.14, détail d'item jusqu'en 8.11 : le shell leur ajoute la hauteur de la tab bar. Un écran migré en CgPage reserveTabBar: tru"
resource: "collega_app/lib/features/shell/app_shell.dart"
tags: ["session-learning"]
timestamp: "2026-09-23T07:48:01.572Z"
x-kage-id: "repo:git-github-com-tistech0-collega:convention:shell-crans-legacy-vs-collega-ui-routes-home-colleges-pour-le-d-tail-ouvert-depu"
x-kage-type: "convention"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_app/lib/features/shell/app_shell.dart", "collega_app/lib/core/router/app_router.dart", "collega_app/lib/features/colleges/presentation/college_detail_screen.dart", "collega_app/lib/core/network/network_errors.dart"]
---

# Shell : écrans legacy vs Collega UI, routes /home/colleges pour le détail ouvert depuis Aujourd'hui

> AppShell. legacyPattern liste les écrans du shell encore en Scaffold Material Profil jusqu'en 8.14, détail d'item jus…

`AppShell._legacyPattern` liste les écrans du shell encore en Scaffold Material (Profil jusqu'en 8.14, détail d'item jusqu'en 8.11) : le shell leur ajoute la hauteur de la tab bar. Un écran migré en `CgPage(reserveTabBar: true)` DOIT sortir de ce motif, sinon la place est réservée deux fois (bouton ancré qui flotte ~86 pt au-dessus de la capsule) — à faire à chaque story d'écran. Le détail collège existe sous `/colleges/:id` (Bibliothèque) et `/home/colleges/:id` (ouvert depuis Aujourd'hui : onglet Aujourd'hui actif, retour « ‹ Aujourd'hui », items poussés sous la même base) ; `CollegeDetailScreen(fromToday:)`. « Hors connexion » seulement si `isNetworkUnreachable(e)` (lib/core/network/network_errors.dart), jamais sur un 500/401.
Verified by: test/features/shell/app_shell_test.dart + revue adversariale 8.6/8.7

## Verification

test/features/shell/app_shell_test.dart + revue adversariale 8.6/8.7

# Citations

[1] explicit_capture (2026-09-23T07:48:01.572Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:convention:shell-crans-legacy-vs-collega-ui-routes-home-colleges-pour-le-d-tail-ouvert-depu","title":"Shell : écrans legacy vs Collega UI, routes /home/colleges pour le détail ouvert depuis Aujourd'hui","summary":"AppShell. legacyPattern liste les écrans du shell encore en Scaffold Material Profil jusqu'en 8.14, détail d'item jusqu'en 8.11 : le shell leur ajoute la hauteur de la tab bar. Un écran migré en CgPage reserveTabBar: tru","body":"`AppShell._legacyPattern` liste les écrans du shell encore en Scaffold Material (Profil jusqu'en 8.14, détail d'item jusqu'en 8.11) : le shell leur ajoute la hauteur de la tab bar. Un écran migré en `CgPage(reserveTabBar: true)` DOIT sortir de ce motif, sinon la place est réservée deux fois (bouton ancré qui flotte ~86 pt au-dessus de la capsule) — à faire à chaque story d'écran. Le détail collège existe sous `/colleges/:id` (Bibliothèque) et `/home/colleges/:id` (ouvert depuis Aujourd'hui : onglet Aujourd'hui actif, retour « ‹ Aujourd'hui », items poussés sous la même base) ; `CollegeDetailScreen(fromToday:)`. « Hors connexion » seulement si `isNetworkUnreachable(e)` (lib/core/network/network_errors.dart), jamais sur un 500/401.\nVerified by: test/features/shell/app_shell_test.dart + revue adversariale 8.6/8.7","type":"convention","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning"],"paths":["collega_app/lib/features/shell/app_shell.dart","collega_app/lib/core/router/app_router.dart","collega_app/lib/features/colleges/presentation/college_detail_screen.dart","collega_app/lib/core/network/network_errors.dart"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-23T07:48:01.572Z"}],"context":{"fact":"`AppShell._legacyPattern` liste les écrans du shell encore en Scaffold Material (Profil jusqu'en 8.14, détail d'item jusqu'en 8.11) : le shell leur ajoute la hauteur de la tab bar. Un écran migré en `CgPage(reserveTabBar: true)` DOIT sortir de ce motif, sinon la place est réservée deux fois (bouton ancré qui flotte ~86 pt au-dessus de la capsule) — à faire à chaque story d'écran. Le détail collège existe sous `/colleges/:id` (Bibliothèque) et `/home/colleges/:id` (ouvert depuis Aujourd'hui : onglet Aujourd'hui actif, retour « ‹ Aujourd'hui », items poussés sous la même base) ; `CollegeDetailScreen(fromToday:)`. « Hors connexion » seulement si `isNetworkUnreachable(e)` (lib/core/network/network_errors.dart), jamais sur un 500/401.\nVerified by: test/features/shell/app_shell_test.dart + revue adversariale 8.6/8.7","verification":"test/features/shell/app_shell_test.dart + revue adversariale 8.6/8.7"},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T07:48:01.572Z","path_fingerprints":[{"path":"collega_app/lib/features/shell/app_shell.dart","sha256":"897f738969ffc72ede083f8cda6726281a038627c0bdcd5c90e20a075b20870f","size":2998},{"path":"collega_app/lib/core/router/app_router.dart","sha256":"4fba3791c4df51781008a94bcf856366734f02247703bf18ce18d17db5253e26","size":6794},{"path":"collega_app/lib/features/colleges/presentation/college_detail_screen.dart","sha256":"92f9e61440022aff2cd1baa393c2d6778aca457ff4d18d5bd24db4a7f30e413f","size":17202},{"path":"collega_app/lib/core/network/network_errors.dart","sha256":"ef7f48caec3b14bc513e9ee36ea88030048742b650d23f86fcb2fa2c0c942fd3","size":538}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":2000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"stale_reasons":[],"estimated_tokens_saved":206},"created_at":"2026-09-23T07:48:01.572Z","updated_at":"2026-09-23T07:48:01.572Z","author_branch":"feat/redesign-ux-ui"}
```

