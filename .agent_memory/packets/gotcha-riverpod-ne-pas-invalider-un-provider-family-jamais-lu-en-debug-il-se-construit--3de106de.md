---
type: "Gotcha"
title: "Riverpod : ne pas invalider un provider family jamais lu (en debug il se construit) → collegeDataVersionProvider"
description: "En Riverpod 2 debug/tests , ref.invalidate collegeDetailProvider id depuis un autre notifier passe par debugAssertCanDependOn , qui CONSTRUIT le provider s'il n'existe pas : son build s'exécute appel réseau inutile, fetc"
resource: "collega_app/lib/features/colleges/colleges_detail_providers.dart"
tags: ["session-learning"]
timestamp: "2026-09-23T09:15:48.936Z"
x-kage-id: "repo:git-github-com-tistech0-collega:gotcha:riverpod-ne-pas-invalider-un-provider-family-jamais-lu-en-debug-il-se-construit-"
x-kage-type: "gotcha"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "verified"
x-kage-paths: ["collega_app/lib/features/colleges/colleges_detail_providers.dart", "collega_app/lib/features/colleges/colleges_import_providers.dart", "collega_app/test/features/colleges/college_import_notifier_test.dart"]
---

# Riverpod : ne pas invalider un provider family jamais lu (en debug il se construit) → collegeDataVersionProvider

> En Riverpod 2 debug/tests , ref.invalidate collegeDetailProvider id depuis un autre notifier passe par debugAssertCan…

En Riverpod 2 (debug/tests), `ref.invalidate(collegeDetailProvider(id))` depuis un autre notifier passe par `_debugAssertCanDependOn`, qui CONSTRUIT le provider s'il n'existe pas : son build s'exécute (appel réseau inutile, fetcher réel non overridé en test → erreurs). Pour recharger le détail d'un collège quand son contenu change (fin d'import/réimport, suppression d'une fiche), on incrémente `collegeDataVersionProvider(collegeId)` (StateProvider.family) que `CollegeDetailNotifier.build` observe : seul un détail vivant se recharge. Depuis la 8.7, `CollegeDetailNotifier.build` synchronise aussi items ET fiches du collège dans Drift (le drill et le bouton « Réviser ce collège · N » lisent Drift), et `CollegeImportNotifier._onGenerationComplete` télécharge les nouvelles fiches (un réimport garde le même college_id, TodayNotifier._synced ne resynchronise pas).
Verified by: flutter test test/features/colleges (147 verts) ; stack trace du test deleteCard avant correctif

## Verification

flutter test test/features/colleges (147 verts) ; stack trace du test deleteCard avant correctif

# Citations

[1] explicit_capture (2026-09-23T07:47:56.410Z)
[2] reverification

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:gotcha:riverpod-ne-pas-invalider-un-provider-family-jamais-lu-en-debug-il-se-construit-","title":"Riverpod : ne pas invalider un provider family jamais lu (en debug il se construit) → collegeDataVersionProvider","summary":"En Riverpod 2 debug/tests , ref.invalidate collegeDetailProvider id depuis un autre notifier passe par debugAssertCanDependOn , qui CONSTRUIT le provider s'il n'existe pas : son build s'exécute appel réseau inutile, fetc","body":"En Riverpod 2 (debug/tests), `ref.invalidate(collegeDetailProvider(id))` depuis un autre notifier passe par `_debugAssertCanDependOn`, qui CONSTRUIT le provider s'il n'existe pas : son build s'exécute (appel réseau inutile, fetcher réel non overridé en test → erreurs). Pour recharger le détail d'un collège quand son contenu change (fin d'import/réimport, suppression d'une fiche), on incrémente `collegeDataVersionProvider(collegeId)` (StateProvider.family) que `CollegeDetailNotifier.build` observe : seul un détail vivant se recharge. Depuis la 8.7, `CollegeDetailNotifier.build` synchronise aussi items ET fiches du collège dans Drift (le drill et le bouton « Réviser ce collège · N » lisent Drift), et `CollegeImportNotifier._onGenerationComplete` télécharge les nouvelles fiches (un réimport garde le même college_id, TodayNotifier._synced ne resynchronise pas).\nVerified by: flutter test test/features/colleges (147 verts) ; stack trace du test deleteCard avant correctif","type":"gotcha","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning"],"paths":["collega_app/lib/features/colleges/colleges_detail_providers.dart","collega_app/lib/features/colleges/colleges_import_providers.dart","collega_app/test/features/colleges/college_import_notifier_test.dart"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-23T07:47:56.410Z"},{"kind":"reverification","at":"2026-09-23T09:15:48.936Z","evidence":"stories 8.10-8.11 (5ed9392, b948dc4) : comportement décrit inchangé ; tests par dossier verts","changed_paths":[{"path":"collega_app/lib/features/colleges/colleges_detail_providers.dart","prior_sha256":"32a4895b91e31f58998c1c9d2ec132ed237b83ba776734edc9e82698107b4021","sha256":"64b4e3b6ad67302275f3fba7ad0f50199072273393a6d972bfa8a8bc5a042da7"}]}],"context":{"fact":"En Riverpod 2 (debug/tests), `ref.invalidate(collegeDetailProvider(id))` depuis un autre notifier passe par `_debugAssertCanDependOn`, qui CONSTRUIT le provider s'il n'existe pas : son build s'exécute (appel réseau inutile, fetcher réel non overridé en test → erreurs). Pour recharger le détail d'un collège quand son contenu change (fin d'import/réimport, suppression d'une fiche), on incrémente `collegeDataVersionProvider(collegeId)` (StateProvider.family) que `CollegeDetailNotifier.build` observe : seul un détail vivant se recharge. Depuis la 8.7, `CollegeDetailNotifier.build` synchronise aussi items ET fiches du collège dans Drift (le drill et le bouton « Réviser ce collège · N » lisent Drift), et `CollegeImportNotifier._onGenerationComplete` télécharge les nouvelles fiches (un réimport garde le même college_id, TodayNotifier._synced ne resynchronise pas).\nVerified by: flutter test test/features/colleges (147 verts) ; stack trace du test deleteCard avant correctif","verification":"flutter test test/features/colleges (147 verts) ; stack trace du test deleteCard avant correctif"},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T09:15:48.936Z","path_fingerprints":[{"path":"collega_app/lib/features/colleges/colleges_detail_providers.dart","sha256":"64b4e3b6ad67302275f3fba7ad0f50199072273393a6d972bfa8a8bc5a042da7","size":8988},{"path":"collega_app/lib/features/colleges/colleges_import_providers.dart","sha256":"4af8cfffa5b26d61afb8d96ebad4d69668f183ac5b7b017b70935f075f6cffb2","size":15247},{"path":"collega_app/test/features/colleges/college_import_notifier_test.dart","sha256":"08ee7817966438fab29d4ee8e99477a6323210161ee1464d49c75d79dbd879cf","size":26692}],"path_fingerprint_policy":"source_hash_staleness","verification":"evidence_reverification"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":8000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":245,"reverified_at":"2026-09-23T09:15:48.936Z"},"created_at":"2026-09-23T07:47:56.410Z","updated_at":"2026-09-23T09:15:48.936Z","author_branch":"feat/redesign-ux-ui"}
```

