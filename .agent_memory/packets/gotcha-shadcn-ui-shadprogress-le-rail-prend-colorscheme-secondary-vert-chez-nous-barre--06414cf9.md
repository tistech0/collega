---
type: "Gotcha"
title: "shadcn_ui ShadProgress : le rail prend colorScheme.secondary (vert chez nous) → barre « pleine » et faux spinners verts"
description: "Dans shadcn ui 0.19.3 lib/src/components/progress.dart:37 39 , le fond de ShadProgress est backgroundColor ?? progressTheme.backgroundColor ?? colorScheme.secondary. Notre secondary est 0xFF3D6B5E vert foncé : une barre"
resource: "collega_app/lib/core/theme/app_theme.dart"
tags: ["session-learning", "shadcn_ui", "theme", "ShadProgress", "secondary"]
timestamp: "2026-09-23T10:05:29.197Z"
x-kage-id: "repo:git-github-com-tistech0-collega:gotcha:shadcn-ui-shadprogress-le-rail-prend-colorscheme-secondary-vert-chez-nous-barre-"
x-kage-type: "gotcha"
x-kage-status: "superseded"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "superseded"
x-kage-paths: ["collega_app/lib/core/theme/app_theme.dart", "collega_app/test/core/theme/app_theme_test.dart"]
x-kage-stack: ["flutter", "shadcn_ui"]
---

# shadcn_ui ShadProgress : le rail prend colorScheme.secondary (vert chez nous) → barre « pleine » et faux spinners verts

> Dans shadcn ui 0.19.3 lib/src/components/progress.dart:37 39 , le fond de ShadProgress est backgroundColor ?? progres…

Dans shadcn_ui 0.19.3 (lib/src/components/progress.dart:37-39), le fond de ShadProgress est backgroundColor ?? progressTheme.backgroundColor ?? colorScheme.secondary. Notre secondary est 0xFF3D6B5E (vert foncé) : une barre de drill à 0 % paraissait déjà pleine, et les `const ShadProgress()` indéterminés utilisés comme spinners (Home session_hero_card, login, register, paywall, planning) ressemblaient à une longue barre verte fine quasi immobile. Fix : progressTheme explicite dans buildShadTheme (color primary, backgroundColor AppColors.progressTrack gris clair). Test : test/core/theme/app_theme_test.dart. À retenir : tout nouveau composant shadcn qui s'appuie sur `secondary` comme couleur neutre sera vert chez nous — vérifier les défauts du composant.
Evidence: Captures iPhone + source shadcn_ui 0.19.3 progress.dart ; test app_theme_test vérifie backgroundColor != secondary.
Verified by: flutter test test/core/theme ; commit 542e3b0 ; validation visuelle iPhone 2026-09-21

## Verification

Captures iPhone + source shadcn_ui 0.19.3 progress.dart ; test app_theme_test vérifie backgroundColor != secondary.

# Citations

[1] explicit_capture (2026-09-21T18:48:59.987Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:gotcha:shadcn-ui-shadprogress-le-rail-prend-colorscheme-secondary-vert-chez-nous-barre-","title":"shadcn_ui ShadProgress : le rail prend colorScheme.secondary (vert chez nous) → barre « pleine » et faux spinners verts","summary":"Dans shadcn ui 0.19.3 lib/src/components/progress.dart:37 39 , le fond de ShadProgress est backgroundColor ?? progressTheme.backgroundColor ?? colorScheme.secondary. Notre secondary est 0xFF3D6B5E vert foncé : une barre","body":"Dans shadcn_ui 0.19.3 (lib/src/components/progress.dart:37-39), le fond de ShadProgress est backgroundColor ?? progressTheme.backgroundColor ?? colorScheme.secondary. Notre secondary est 0xFF3D6B5E (vert foncé) : une barre de drill à 0 % paraissait déjà pleine, et les `const ShadProgress()` indéterminés utilisés comme spinners (Home session_hero_card, login, register, paywall, planning) ressemblaient à une longue barre verte fine quasi immobile. Fix : progressTheme explicite dans buildShadTheme (color primary, backgroundColor AppColors.progressTrack gris clair). Test : test/core/theme/app_theme_test.dart. À retenir : tout nouveau composant shadcn qui s'appuie sur `secondary` comme couleur neutre sera vert chez nous — vérifier les défauts du composant.\nEvidence: Captures iPhone + source shadcn_ui 0.19.3 progress.dart ; test app_theme_test vérifie backgroundColor != secondary.\nVerified by: flutter test test/core/theme ; commit 542e3b0 ; validation visuelle iPhone 2026-09-21","type":"gotcha","scope":"repo","visibility":"team","sensitivity":"internal","status":"superseded","confidence":0.7,"tags":["session-learning","shadcn_ui","theme","ShadProgress","secondary"],"paths":["collega_app/lib/core/theme/app_theme.dart","collega_app/test/core/theme/app_theme_test.dart"],"stack":["flutter","shadcn_ui"],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-21T18:48:59.987Z"}],"context":{"fact":"Dans shadcn_ui 0.19.3 (lib/src/components/progress.dart:37-39), le fond de ShadProgress est backgroundColor ?? progressTheme.backgroundColor ?? colorScheme.secondary. Notre secondary est 0xFF3D6B5E (vert foncé) : une barre de drill à 0 % paraissait déjà pleine, et les `const ShadProgress()` indéterminés utilisés comme spinners (Home session_hero_card, login, register, paywall, planning) ressemblaient à une longue barre verte fine quasi immobile. Fix : progressTheme explicite dans buildShadTheme (color primary, backgroundColor AppColors.progressTrack gris clair). Test : test/core/theme/app_theme_test.dart. À retenir : tout nouveau composant shadcn qui s'appuie sur `secondary` comme couleur neutre sera vert chez nous — vérifier les défauts du composant.\nEvidence: Captures iPhone + source shadcn_ui 0.19.3 progress.dart ; test app_theme_test vérifie backgroundColor != secondary.\nVerified by: flutter test test/core/theme ; commit 542e3b0 ; validation visuelle iPhone 2026-09-21","verification":"Captures iPhone + source shadcn_ui 0.19.3 progress.dart ; test app_theme_test vérifie backgroundColor != secondary."},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T10:05:29.197Z","path_fingerprints":[{"path":"collega_app/lib/core/theme/app_theme.dart","sha256":"530e7f25e1081575d7cc0b08bc308daa3604edb2ff5dd1d1609dd01ec9ddcf91","size":2930},{"path":"collega_app/test/core/theme/app_theme_test.dart","sha256":"24b93f9a977a5bcd34da0cb0e6574959853162ab5736de5256716e47ab40a816","size":1139}],"path_fingerprint_policy":"source_hash_staleness","verification":"evidence_reverification","stale_reported_at":"2026-09-23T12:26:29.633Z","superseded_at":"2026-09-23T15:45:15.633Z","superseded_by":"repo:git-github-com-tistech0-collega:decision:shadcn-ui-et-le-th-me-v1-retir-s-story-8-15-plus-de-shadprogress-garde-fou-no-v1","superseded_reason":"shadcn_ui et app_theme.dart retirés en story 8.15 (18c6a25) ; le piège ne peut plus se produire"},"edges":[{"relation":"superseded_by","to":"repo:git-github-com-tistech0-collega:decision:shadcn-ui-et-le-th-me-v1-retir-s-story-8-15-plus-de-shadprogress-garde-fou-no-v1","evidence":"shadcn_ui et app_theme.dart retirés en story 8.15 (18c6a25) ; le piège ne peut plus se produire","created_at":"2026-09-23T15:45:15.633Z"}],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":3,"reports_stale":1,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":8000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":247,"total_uses":3,"reverified_at":"2026-09-23T10:05:29.197Z","stale":true,"stale_reasons":["packet status is superseded","user or agent reported this memory stale","all referenced paths are missing: collega_app/lib/core/theme/app_theme.dart, collega_app/test/core/theme/app_theme_test.dart"],"suggested_action":"mark_stale","last_accessed_at":"2026-09-22T18:38:48.733Z","superseded_by":"repo:git-github-com-tistech0-collega:decision:shadcn-ui-et-le-th-me-v1-retir-s-story-8-15-plus-de-shadprogress-garde-fou-no-v1","superseded_reason":"shadcn_ui et app_theme.dart retirés en story 8.15 (18c6a25) ; le piège ne peut plus se produire"},"created_at":"2026-09-21T18:48:59.987Z","updated_at":"2026-09-23T15:45:15.633Z","author_branch":"feat/story-7.11-upload-chunked"}
```

