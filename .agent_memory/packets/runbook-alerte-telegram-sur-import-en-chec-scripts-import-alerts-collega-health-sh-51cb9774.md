---
type: "Runbook"
title: "Alerte Telegram sur import en échec : scripts.import_alerts + collega-health.sh"
description: "Le script de santé du NAS collega backend/ops/nas/collega health.sh, User Script Unraid chaque minute lance docker exec collega api 1 python m scripts.import alerts ; chaque ligne imprimée = un job passé en failed depuis"
resource: "collega_backend/scripts/import_alerts.py"
tags: ["session-learning", "telegram", "supervision", "nas", "imports"]
timestamp: "2026-09-26T18:11:09.424Z"
x-kage-id: "repo:git-github-com-tistech0-collega:runbook:alerte-telegram-sur-import-en-chec-scripts-import-alerts-collega-health-sh-17904"
x-kage-type: "runbook"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_backend/scripts/import_alerts.py", "collega_backend/ops/nas/collega-health.sh"]
---

# Alerte Telegram sur import en échec : scripts.import_alerts + collega-health.sh

> Le script de santé du NAS collega backend/ops/nas/collega health.sh, User Script Unraid chaque minute lance docker ex…

Le script de santé du NAS (collega_backend/ops/nas/collega-health.sh, User Script Unraid chaque minute) lance `docker exec collega-api-1 python -m scripts.import_alerts` ; chaque ligne imprimée = un job passé en failed depuis le passage précédent (« collège — e-mail : message court »), envoyée par notify « Collega : import en échec » en niveau alert. Point de reprise : app_settings clé import_alerts_since (ISO 8601), initialisé à « maintenant » au tout premier passage (pas de rafale historique). Pour rejouer : supprimer la ligne app_settings. Une panne de la commande n'interrompt jamais la sonde ; son stderr va dans /tmp/collega-import-alerts.log sur le NAS. Un arrêt d'import par l'admin passe aussi en failed et déclenche l'alerte. Piège de test : un trigger Postgres update_generation_jobs_updated_at écrase toute écriture explicite de generation_jobs.updated_at (les tests désactivent le trigger).
Evidence: tests/scripts/test_import_alerts_pg.py verts ; bash -n ; revue finale.

## Verification

tests/scripts/test_import_alerts_pg.py verts ; bash -n ; revue finale.

# Citations

[1] explicit_capture (2026-09-26T18:11:09.424Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:runbook:alerte-telegram-sur-import-en-chec-scripts-import-alerts-collega-health-sh-17904","title":"Alerte Telegram sur import en échec : scripts.import_alerts + collega-health.sh","summary":"Le script de santé du NAS collega backend/ops/nas/collega health.sh, User Script Unraid chaque minute lance docker exec collega api 1 python m scripts.import alerts ; chaque ligne imprimée = un job passé en failed depuis","body":"Le script de santé du NAS (collega_backend/ops/nas/collega-health.sh, User Script Unraid chaque minute) lance `docker exec collega-api-1 python -m scripts.import_alerts` ; chaque ligne imprimée = un job passé en failed depuis le passage précédent (« collège — e-mail : message court »), envoyée par notify « Collega : import en échec » en niveau alert. Point de reprise : app_settings clé import_alerts_since (ISO 8601), initialisé à « maintenant » au tout premier passage (pas de rafale historique). Pour rejouer : supprimer la ligne app_settings. Une panne de la commande n'interrompt jamais la sonde ; son stderr va dans /tmp/collega-import-alerts.log sur le NAS. Un arrêt d'import par l'admin passe aussi en failed et déclenche l'alerte. Piège de test : un trigger Postgres update_generation_jobs_updated_at écrase toute écriture explicite de generation_jobs.updated_at (les tests désactivent le trigger).\nEvidence: tests/scripts/test_import_alerts_pg.py verts ; bash -n ; revue finale.","type":"runbook","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","telegram","supervision","nas","imports"],"paths":["collega_backend/scripts/import_alerts.py","collega_backend/ops/nas/collega-health.sh"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-26T18:11:09.424Z"}],"context":{"fact":"Le script de santé du NAS (collega_backend/ops/nas/collega-health.sh, User Script Unraid chaque minute) lance `docker exec collega-api-1 python -m scripts.import_alerts` ; chaque ligne imprimée = un job passé en failed depuis le passage précédent (« collège — e-mail : message court »), envoyée par notify « Collega : import en échec » en niveau alert. Point de reprise : app_settings clé import_alerts_since (ISO 8601), initialisé à « maintenant » au tout premier passage (pas de rafale historique). Pour rejouer : supprimer la ligne app_settings. Une panne de la commande n'interrompt jamais la sonde ; son stderr va dans /tmp/collega-import-alerts.log sur le NAS. Un arrêt d'import par l'admin passe aussi en failed et déclenche l'alerte. Piège de test : un trigger Postgres update_generation_jobs_updated_at écrase toute écriture explicite de generation_jobs.updated_at (les tests désactivent le trigger).\nEvidence: tests/scripts/test_import_alerts_pg.py verts ; bash -n ; revue finale.","verification":"tests/scripts/test_import_alerts_pg.py verts ; bash -n ; revue finale."},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-26T18:11:09.424Z","path_fingerprints":[{"path":"collega_backend/scripts/import_alerts.py","sha256":"4fd294518f5689bceede1a903de5269d31b1b6526b40c889172acd7a8bcd1ae2","size":2657},{"path":"collega_backend/ops/nas/collega-health.sh","sha256":"a992aa11c46249b04f967d8ad765c581224bbbb507bed0854c4af23ff6f4932a","size":3665}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":2000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"stale_reasons":[],"estimated_tokens_saved":248},"created_at":"2026-09-26T18:11:09.424Z","updated_at":"2026-09-26T18:11:09.424Z","author_branch":"feat/console-pilotage"}
```

