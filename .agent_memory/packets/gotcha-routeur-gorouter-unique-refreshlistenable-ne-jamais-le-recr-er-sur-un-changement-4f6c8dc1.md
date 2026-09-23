---
type: "Gotcha"
title: "Routeur : GoRouter unique + refreshListenable (ne jamais le recréer sur un changement d'auth)"
description: "Avant 8.12, routerProvider faisait ref.watch authProvider : chaque changement d'état de connexion login → AsyncLoading, updateProfile, refreshSubscription, forceLogout recréait un GoRouter qui repartait de initialLocatio"
resource: "collega_app/lib/core/router/app_router.dart"
tags: ["session-learning"]
timestamp: "2026-09-23T10:05:28.873Z"
x-kage-id: "repo:git-github-com-tistech0-collega:gotcha:routeur-gorouter-unique-refreshlistenable-ne-jamais-le-recr-er-sur-un-changement"
x-kage-type: "gotcha"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "verified"
x-kage-paths: ["collega_app/lib/core/router/app_router.dart", "collega_app/lib/features/auth/auth_providers.dart", "collega_app/test/core/router/app_router_test.dart"]
---

# Routeur : GoRouter unique + refreshListenable (ne jamais le recréer sur un changement d'auth)

> Avant 8.12, routerProvider faisait ref.watch authProvider : chaque changement d'état de connexion login → AsyncLoadin…

Avant 8.12, `routerProvider` faisait `ref.watch(authProvider)` : chaque changement d'état de connexion (login → AsyncLoading, updateProfile, refreshSubscription, forceLogout) recréait un GoRouter qui repartait de `initialLocation` — l'écran courant disparaissait (erreur de connexion jamais affichée, Profil renvoyé sur Aujourd'hui) et `notificationsServiceProvider` gardait un routeur périmé. Désormais (app_router.dart) : un seul GoRouter, `refreshListenable` = ValueNotifier incrémenté par `ref.listen(authProvider)`, `redirect` lit `ref.read(authProvider)` et ne décide rien tant que `!hasValue` ; `initialLocation: '/splash'` (fond neutre) redirigé vers `/welcome`, `/home` ou `/paywall`. `AuthNotifier.login` garde la valeur précédente (`AsyncLoading().copyWithPrevious(state)`). Les tests d'écran avec un routeur maison ne voient pas ce défaut : tester avec le vrai `routerProvider` (test/core/router/app_router_test.dart « revue 8.12 »).
Verified by: test « connexion ratée : on reste sur la connexion et l'erreur s'affiche » (rouge avant, vert après)

## Verification

test « connexion ratée : on reste sur la connexion et l'erreur s'affiche » (rouge avant, vert après)

# Citations

[1] explicit_capture (2026-09-23T10:05:04.563Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:gotcha:routeur-gorouter-unique-refreshlistenable-ne-jamais-le-recr-er-sur-un-changement","title":"Routeur : GoRouter unique + refreshListenable (ne jamais le recréer sur un changement d'auth)","summary":"Avant 8.12, routerProvider faisait ref.watch authProvider : chaque changement d'état de connexion login → AsyncLoading, updateProfile, refreshSubscription, forceLogout recréait un GoRouter qui repartait de initialLocatio","body":"Avant 8.12, `routerProvider` faisait `ref.watch(authProvider)` : chaque changement d'état de connexion (login → AsyncLoading, updateProfile, refreshSubscription, forceLogout) recréait un GoRouter qui repartait de `initialLocation` — l'écran courant disparaissait (erreur de connexion jamais affichée, Profil renvoyé sur Aujourd'hui) et `notificationsServiceProvider` gardait un routeur périmé. Désormais (app_router.dart) : un seul GoRouter, `refreshListenable` = ValueNotifier incrémenté par `ref.listen(authProvider)`, `redirect` lit `ref.read(authProvider)` et ne décide rien tant que `!hasValue` ; `initialLocation: '/splash'` (fond neutre) redirigé vers `/welcome`, `/home` ou `/paywall`. `AuthNotifier.login` garde la valeur précédente (`AsyncLoading().copyWithPrevious(state)`). Les tests d'écran avec un routeur maison ne voient pas ce défaut : tester avec le vrai `routerProvider` (test/core/router/app_router_test.dart « revue 8.12 »).\nVerified by: test « connexion ratée : on reste sur la connexion et l'erreur s'affiche » (rouge avant, vert après)","type":"gotcha","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning"],"paths":["collega_app/lib/core/router/app_router.dart","collega_app/lib/features/auth/auth_providers.dart","collega_app/test/core/router/app_router_test.dart"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-23T10:05:04.563Z"}],"context":{"fact":"Avant 8.12, `routerProvider` faisait `ref.watch(authProvider)` : chaque changement d'état de connexion (login → AsyncLoading, updateProfile, refreshSubscription, forceLogout) recréait un GoRouter qui repartait de `initialLocation` — l'écran courant disparaissait (erreur de connexion jamais affichée, Profil renvoyé sur Aujourd'hui) et `notificationsServiceProvider` gardait un routeur périmé. Désormais (app_router.dart) : un seul GoRouter, `refreshListenable` = ValueNotifier incrémenté par `ref.listen(authProvider)`, `redirect` lit `ref.read(authProvider)` et ne décide rien tant que `!hasValue` ; `initialLocation: '/splash'` (fond neutre) redirigé vers `/welcome`, `/home` ou `/paywall`. `AuthNotifier.login` garde la valeur précédente (`AsyncLoading().copyWithPrevious(state)`). Les tests d'écran avec un routeur maison ne voient pas ce défaut : tester avec le vrai `routerProvider` (test/core/router/app_router_test.dart « revue 8.12 »).\nVerified by: test « connexion ratée : on reste sur la connexion et l'erreur s'affiche » (rouge avant, vert après)","verification":"test « connexion ratée : on reste sur la connexion et l'erreur s'affiche » (rouge avant, vert après)"},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T10:05:28.873Z","path_fingerprints":[{"path":"collega_app/lib/core/router/app_router.dart","sha256":"4439baf534e2a6efa139c99f58d34e6428534b52c7c967f71facab1b72a32216","size":8507},{"path":"collega_app/lib/features/auth/auth_providers.dart","sha256":"218185e07cb9054b214adac1f00a372c6b46491f5fce36fa8887fc3372d2015e","size":9216},{"path":"collega_app/test/core/router/app_router_test.dart","sha256":"01e6fa7b97009c8376727d932059aef8847106313cbf185b92bb3919f2402bf1","size":8799}],"path_fingerprint_policy":"source_hash_staleness","verification":"evidence_reverification"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":8000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":265,"reverified_at":"2026-09-23T10:05:28.873Z"},"created_at":"2026-09-23T10:05:04.563Z","updated_at":"2026-09-23T10:05:28.873Z","author_branch":"feat/redesign-ux-ui"}
```

