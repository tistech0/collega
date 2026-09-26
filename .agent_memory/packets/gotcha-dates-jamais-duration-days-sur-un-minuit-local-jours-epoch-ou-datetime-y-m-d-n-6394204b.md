---
type: "Gotcha"
title: "Dates : jamais ± Duration(days) sur un minuit local — jours epoch ou DateTime(y, m, d ± n)"
description: "En France CEST→CET le dernier dimanche d'octobre, l'inverse fin mars , date.add const Duration days: n sur un minuit local donne 23 h la veille ou 1 h du jour : tronqué au jour, un planning décalé ne se prolongeait pas e"
resource: "collega_app/lib/core/utils/epoch_day.dart"
tags: ["session-learning"]
timestamp: "2026-09-23T10:05:27.446Z"
x-kage-id: "repo:git-github-com-tistech0-collega:gotcha:dates-jamais-duration-days-sur-un-minuit-local-jours-epoch-ou-datetime-y-m-d-n-1"
x-kage-type: "gotcha"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "verified"
x-kage-paths: ["collega_app/lib/core/utils/epoch_day.dart", "collega_app/lib/features/planning/planning_providers.dart", "collega_app/lib/features/planning/domain/planning_models.dart", "collega_app/lib/features/planning/presentation/planning_screen.dart", "collega_app/test/features/planning/planning_notifier_test.dart"]
---

# Dates : jamais ± Duration(days) sur un minuit local — jours epoch ou DateTime(y, m, d ± n)

> En France CEST→CET le dernier dimanche d'octobre, l'inverse fin mars , date.add const Duration days: n sur un minuit …

En France (CEST→CET le dernier dimanche d'octobre, l'inverse fin mars), `date.add(const Duration(days: n))` sur un minuit local donne 23 h la veille ou 1 h du jour : tronqué au jour, un planning décalé ne se prolongeait pas (examen le 25 oct.), une annulation retirait 2 jours, l'examen par défaut tombait à J+29. Règle du projet : raisonner en jours civils — `epochDayOf` / `dateOfEpochDay` (lib/core/utils/epoch_day.dart), `PlanningConfig.withEndDay(epochDay)`, ou `DateTime(y, m, d + n)`. Les tests tournent dans le fuseau de la machine (Europe/Paris ici) : un test aux dates 25 oct. 2026 / 28 mars 2027 couvre le cas (test/features/planning/planning_notifier_test.dart « revue 8.9 »).
Verified by: flutter test test/features/planning (45 verts), reproduit par la revue sous TZ=Europe/Paris

## Verification

flutter test test/features/planning (45 verts), reproduit par la revue sous TZ=Europe/Paris

# Citations

[1] explicit_capture (2026-09-23T08:27:09.166Z)
[2] reverification

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:gotcha:dates-jamais-duration-days-sur-un-minuit-local-jours-epoch-ou-datetime-y-m-d-n-1","title":"Dates : jamais ± Duration(days) sur un minuit local — jours epoch ou DateTime(y, m, d ± n)","summary":"En France CEST→CET le dernier dimanche d'octobre, l'inverse fin mars , date.add const Duration days: n sur un minuit local donne 23 h la veille ou 1 h du jour : tronqué au jour, un planning décalé ne se prolongeait pas e","body":"En France (CEST→CET le dernier dimanche d'octobre, l'inverse fin mars), `date.add(const Duration(days: n))` sur un minuit local donne 23 h la veille ou 1 h du jour : tronqué au jour, un planning décalé ne se prolongeait pas (examen le 25 oct.), une annulation retirait 2 jours, l'examen par défaut tombait à J+29. Règle du projet : raisonner en jours civils — `epochDayOf` / `dateOfEpochDay` (lib/core/utils/epoch_day.dart), `PlanningConfig.withEndDay(epochDay)`, ou `DateTime(y, m, d + n)`. Les tests tournent dans le fuseau de la machine (Europe/Paris ici) : un test aux dates 25 oct. 2026 / 28 mars 2027 couvre le cas (test/features/planning/planning_notifier_test.dart « revue 8.9 »).\nVerified by: flutter test test/features/planning (45 verts), reproduit par la revue sous TZ=Europe/Paris","type":"gotcha","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning"],"paths":["collega_app/lib/core/utils/epoch_day.dart","collega_app/lib/features/planning/planning_providers.dart","collega_app/lib/features/planning/domain/planning_models.dart","collega_app/lib/features/planning/presentation/planning_screen.dart","collega_app/test/features/planning/planning_notifier_test.dart"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-23T08:27:09.166Z"},{"kind":"reverification","at":"2026-09-23T08:33:14.668Z","evidence":"8de2c21 : ajout outil de test (kTestTools, resetDay) sans changer le comportement décrit","changed_paths":[{"path":"collega_app/lib/features/planning/presentation/planning_screen.dart","prior_sha256":"773bf509dae78831d05544f40b757412d8467dbd5d825b6943ba566fa5d18f06","sha256":"06263bd592b1ea8b838c2232ac1a26fcf493867df1f08616f0c2ac232f306399"}]}],"context":{"fact":"En France (CEST→CET le dernier dimanche d'octobre, l'inverse fin mars), `date.add(const Duration(days: n))` sur un minuit local donne 23 h la veille ou 1 h du jour : tronqué au jour, un planning décalé ne se prolongeait pas (examen le 25 oct.), une annulation retirait 2 jours, l'examen par défaut tombait à J+29. Règle du projet : raisonner en jours civils — `epochDayOf` / `dateOfEpochDay` (lib/core/utils/epoch_day.dart), `PlanningConfig.withEndDay(epochDay)`, ou `DateTime(y, m, d + n)`. Les tests tournent dans le fuseau de la machine (Europe/Paris ici) : un test aux dates 25 oct. 2026 / 28 mars 2027 couvre le cas (test/features/planning/planning_notifier_test.dart « revue 8.9 »).\nVerified by: flutter test test/features/planning (45 verts), reproduit par la revue sous TZ=Europe/Paris","verification":"flutter test test/features/planning (45 verts), reproduit par la revue sous TZ=Europe/Paris"},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T10:05:27.446Z","path_fingerprints":[{"path":"collega_app/lib/core/utils/epoch_day.dart","sha256":"773adb8e19473a61eb5075d444d3b708fdaa514f15abfdaaa1c7b494c0913d53","size":564},{"path":"collega_app/lib/features/planning/planning_providers.dart","sha256":"ad9c150bff46f9f1349727ec92326439e963d941a5b9d5f9696d7580dc2c8c21","size":5713},{"path":"collega_app/lib/features/planning/domain/planning_models.dart","sha256":"33339b0651ff83b0300234aa0bb76cd708f62b9ce5a7f6ec104ecbc82ba1acfe","size":1213},{"path":"collega_app/lib/features/planning/presentation/planning_screen.dart","sha256":"06263bd592b1ea8b838c2232ac1a26fcf493867df1f08616f0c2ac232f306399","size":23708},{"path":"collega_app/test/features/planning/planning_notifier_test.dart","sha256":"c7f41fb85dfef4cdf5a976c0b35ca2a3722f4b19cc22d98b7f0a31b5a99e0623","size":6564}],"path_fingerprint_policy":"source_hash_staleness","verification":"evidence_reverification"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":12,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":8000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":199,"reverified_at":"2026-09-23T10:05:27.446Z","total_uses":12,"last_accessed_at":"2026-09-26T12:54:46.061Z"},"created_at":"2026-09-23T08:27:09.166Z","updated_at":"2026-09-23T10:05:27.446Z","author_branch":"feat/redesign-ux-ui"}
```

