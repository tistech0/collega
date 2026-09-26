---
type: "Decision"
title: "Console admin de pilotage : modules ES sans build, assets générés depuis l'app"
description: "La console admin collega backend/app/static/admin/ est découpée en modules ES natifs sans étape de build ni dépendance npm : index.html coquille , css/tokens.css tokens repris de collega app/lib/core/ui/tokens , css/ui.c"
resource: "collega_backend/app/static/admin/js/main.js"
tags: ["session-learning", "console", "admin", "front", "generation"]
timestamp: "2026-09-26T18:10:56.561Z"
x-kage-id: "repo:git-github-com-tistech0-collega:decision:console-admin-de-pilotage-modules-es-sans-build-assets-g-n-r-s-depuis-lapp-17904"
x-kage-type: "decision"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_backend/app/static/admin/js/main.js", "collega_backend/scripts/gen_admin_assets.py", "collega_backend/app/core/college_catalog.py", "collega_backend/tests/api/test_admin_front_assets.py"]
---

# Console admin de pilotage : modules ES sans build, assets générés depuis l'app

> La console admin collega backend/app/static/admin/ est découpée en modules ES natifs sans étape de build ni dépendanc…

La console admin (collega_backend/app/static/admin/) est découpée en modules ES natifs sans étape de build ni dépendance npm : index.html (coquille), css/tokens.css (tokens repris de collega_app/lib/core/ui/tokens), css/ui.css, js/{main,api,router,ui}.js et un module par écran dans js/views/. Contrat d'une vue : export async function render(root, params) qui peut renvoyer une fonction de nettoyage (arrêt des rafraîchissements) ; main.js protège la navigation par un renderToken et attrape les erreurs de vue. Tout texte venant de la base passe par textContent via h() ; innerHTML seulement pour ICONS[...] (test test_admin_front_n_utilise_pas_innerhtml_hors_icones). icons.js et app/core/college_catalog.py sont GÉNÉRÉS depuis l'app (cg_icon.dart, college_catalog.dart) par `python -m scripts.gen_admin_assets` ; `--check` et tests/scripts/test_gen_admin_assets.py échouent s'ils ne sont pas à jour : après une nouvelle icône ou un nouveau collège dans l'app, relancer le générateur. Polices Instrument Sans servies en .ttf copiés de l'app.
Evidence: Branche feat/console-pilotage, tests test_admin_front_assets.py et test_gen_admin_assets.py verts, revue finale.

## Verification

Branche feat/console-pilotage, tests test_admin_front_assets.py et test_gen_admin_assets.py verts, revue finale.

# Citations

[1] explicit_capture (2026-09-26T18:10:56.561Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:decision:console-admin-de-pilotage-modules-es-sans-build-assets-g-n-r-s-depuis-lapp-17904","title":"Console admin de pilotage : modules ES sans build, assets générés depuis l'app","summary":"La console admin collega backend/app/static/admin/ est découpée en modules ES natifs sans étape de build ni dépendance npm : index.html coquille , css/tokens.css tokens repris de collega app/lib/core/ui/tokens , css/ui.c","body":"La console admin (collega_backend/app/static/admin/) est découpée en modules ES natifs sans étape de build ni dépendance npm : index.html (coquille), css/tokens.css (tokens repris de collega_app/lib/core/ui/tokens), css/ui.css, js/{main,api,router,ui}.js et un module par écran dans js/views/. Contrat d'une vue : export async function render(root, params) qui peut renvoyer une fonction de nettoyage (arrêt des rafraîchissements) ; main.js protège la navigation par un renderToken et attrape les erreurs de vue. Tout texte venant de la base passe par textContent via h() ; innerHTML seulement pour ICONS[...] (test test_admin_front_n_utilise_pas_innerhtml_hors_icones). icons.js et app/core/college_catalog.py sont GÉNÉRÉS depuis l'app (cg_icon.dart, college_catalog.dart) par `python -m scripts.gen_admin_assets` ; `--check` et tests/scripts/test_gen_admin_assets.py échouent s'ils ne sont pas à jour : après une nouvelle icône ou un nouveau collège dans l'app, relancer le générateur. Polices Instrument Sans servies en .ttf copiés de l'app.\nEvidence: Branche feat/console-pilotage, tests test_admin_front_assets.py et test_gen_admin_assets.py verts, revue finale.","type":"decision","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","console","admin","front","generation"],"paths":["collega_backend/app/static/admin/js/main.js","collega_backend/scripts/gen_admin_assets.py","collega_backend/app/core/college_catalog.py","collega_backend/tests/api/test_admin_front_assets.py"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-26T18:10:56.561Z"}],"context":{"fact":"La console admin (collega_backend/app/static/admin/) est découpée en modules ES natifs sans étape de build ni dépendance npm : index.html (coquille), css/tokens.css (tokens repris de collega_app/lib/core/ui/tokens), css/ui.css, js/{main,api,router,ui}.js et un module par écran dans js/views/. Contrat d'une vue : export async function render(root, params) qui peut renvoyer une fonction de nettoyage (arrêt des rafraîchissements) ; main.js protège la navigation par un renderToken et attrape les erreurs de vue. Tout texte venant de la base passe par textContent via h() ; innerHTML seulement pour ICONS[...] (test test_admin_front_n_utilise_pas_innerhtml_hors_icones). icons.js et app/core/college_catalog.py sont GÉNÉRÉS depuis l'app (cg_icon.dart, college_catalog.dart) par `python -m scripts.gen_admin_assets` ; `--check` et tests/scripts/test_gen_admin_assets.py échouent s'ils ne sont pas à jour : après une nouvelle icône ou un nouveau collège dans l'app, relancer le générateur. Polices Instrument Sans servies en .ttf copiés de l'app.\nEvidence: Branche feat/console-pilotage, tests test_admin_front_assets.py et test_gen_admin_assets.py verts, revue finale.","verification":"Branche feat/console-pilotage, tests test_admin_front_assets.py et test_gen_admin_assets.py verts, revue finale."},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-26T18:10:56.561Z","path_fingerprints":[{"path":"collega_backend/app/static/admin/js/main.js","sha256":"c1ca5bc8f9643b63b15554fa1fb12cbc4294a8f7b6f73bec37721125c7cb3f9c","size":4596},{"path":"collega_backend/scripts/gen_admin_assets.py","sha256":"f7894d80783c4df5a7c26b010f84dee50428484a4978845fd80678ecbc235804","size":2919},{"path":"collega_backend/app/core/college_catalog.py","sha256":"1fa666fc7d4cb2c3e2ec544d8a2beacd9cf1f485e52c43553a542a93a1657e72","size":1497},{"path":"collega_backend/tests/api/test_admin_front_assets.py","sha256":"2440a4703216a3a0dc8fa48efda2bc6be6c5d2d7007ad84dc6dfca1374741d27","size":1999}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":4000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"stale_reasons":[],"estimated_tokens_saved":292},"created_at":"2026-09-26T18:10:56.561Z","updated_at":"2026-09-26T18:10:56.561Z","author_branch":"feat/console-pilotage"}
```

