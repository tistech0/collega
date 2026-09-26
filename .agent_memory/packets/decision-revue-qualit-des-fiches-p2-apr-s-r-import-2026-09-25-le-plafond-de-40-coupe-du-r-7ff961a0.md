---
type: "Decision"
title: "Revue qualité des fiches p2 après réimport (2026-09-25) : le plafond de 40 coupe du rang A en fin d'item"
description: "Revue du 2026 09 25 des 2186 fiches p2 65 items, 3 collèges , menée comme celle du 2026 09 24 504 fiches p1 . Couverture du rang A : environ 3/10 avant ; environ 95 % en cancéro, 90 % en pneumo et 80 % en hémato après. F"
resource: "collega_backend/app/services/generation/claude_client.py"
tags: ["session-learning", "chantier-4", "qualité-fiches", "plafond-40", "revue"]
timestamp: "2026-09-25T08:58:51.254Z"
x-kage-id: "repo:git-github-com-tistech0-collega:decision:revue-qualit-des-fiches-p2-apr-s-r-import-2026-09-25-le-plafond-de-40-coupe-du-r"
x-kage-type: "decision"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_backend/app/services/generation/claude_client.py", "_bmad-output/planning-artifacts/chantier-4-couts-claude-spec.md"]
---

# Revue qualité des fiches p2 après réimport (2026-09-25) : le plafond de 40 coupe du rang A en fin d'item

> Revue du 2026 09 25 des 2186 fiches p2 65 items, 3 collèges , menée comme celle du 2026 09 24 504 fiches p1 . Couvert…

Revue du 2026-09-25 des 2186 fiches p2 (65 items, 3 collèges), menée comme celle du 2026-09-24 (504 fiches p1). Couverture du rang A : environ 3/10 avant ; environ 95 % en cancéro, 90 % en pneumo et 80 % en hémato après. Fidélité : 9 à 9,75/10. Deux petites erreurs seulement : item 226, fiche ECG « V1 à V4 » alors que le texte dit « V1 à V3 » coupé sur deux lignes ; item 75, une précision non sourcée. Aucune fiche hors sujet. Le découpage est exact sur 65/65 items. Défaut principal : 14 items dépassent 40 fiches (213 : 56, 216 : 53, 329 : 51). Claude rédige dans l'ordre du texte et claude_client garde les 40 premières, donc les sections de fin, y compris du rang A, sont perdues : hémophilie en 216, volet pédiatrique en 220, hémovigilance en 329. Correctif sans coût proposé : tronquer le rang B avant le rang A. Défauts de forme restants : environ 10 % de versos en liste de 6 éléments ou plus, environ 65 questions composées « X et Y ? ». Coût réel : environ 4,80 € pour les 3 collèges.
Evidence: Export prod item_generations claude-sonnet-5:p2 ; 3 revues par collège ; logs worker « Item N : X fiches, tronqué à 40 » ; texte item 226 ligne « onde T négative de V1 à / V3 »

## Verification

Export prod item_generations claude-sonnet-5:p2 ; 3 revues par collège ; logs worker « Item N : X fiches, tronqué à 40 » ; texte item 226 ligne « onde T négative de V1 à / V3 »

# Citations

[1] explicit_capture (2026-09-25T08:58:51.254Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:decision:revue-qualit-des-fiches-p2-apr-s-r-import-2026-09-25-le-plafond-de-40-coupe-du-r","title":"Revue qualité des fiches p2 après réimport (2026-09-25) : le plafond de 40 coupe du rang A en fin d'item","summary":"Revue du 2026 09 25 des 2186 fiches p2 65 items, 3 collèges , menée comme celle du 2026 09 24 504 fiches p1 . Couverture du rang A : environ 3/10 avant ; environ 95 % en cancéro, 90 % en pneumo et 80 % en hémato après. F","body":"Revue du 2026-09-25 des 2186 fiches p2 (65 items, 3 collèges), menée comme celle du 2026-09-24 (504 fiches p1). Couverture du rang A : environ 3/10 avant ; environ 95 % en cancéro, 90 % en pneumo et 80 % en hémato après. Fidélité : 9 à 9,75/10. Deux petites erreurs seulement : item 226, fiche ECG « V1 à V4 » alors que le texte dit « V1 à V3 » coupé sur deux lignes ; item 75, une précision non sourcée. Aucune fiche hors sujet. Le découpage est exact sur 65/65 items. Défaut principal : 14 items dépassent 40 fiches (213 : 56, 216 : 53, 329 : 51). Claude rédige dans l'ordre du texte et claude_client garde les 40 premières, donc les sections de fin, y compris du rang A, sont perdues : hémophilie en 216, volet pédiatrique en 220, hémovigilance en 329. Correctif sans coût proposé : tronquer le rang B avant le rang A. Défauts de forme restants : environ 10 % de versos en liste de 6 éléments ou plus, environ 65 questions composées « X et Y ? ». Coût réel : environ 4,80 € pour les 3 collèges.\nEvidence: Export prod item_generations claude-sonnet-5:p2 ; 3 revues par collège ; logs worker « Item N : X fiches, tronqué à 40 » ; texte item 226 ligne « onde T négative de V1 à / V3 »","type":"decision","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","chantier-4","qualité-fiches","plafond-40","revue"],"paths":["collega_backend/app/services/generation/claude_client.py","_bmad-output/planning-artifacts/chantier-4-couts-claude-spec.md"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-25T08:58:51.254Z"}],"context":{"fact":"Revue du 2026-09-25 des 2186 fiches p2 (65 items, 3 collèges), menée comme celle du 2026-09-24 (504 fiches p1). Couverture du rang A : environ 3/10 avant ; environ 95 % en cancéro, 90 % en pneumo et 80 % en hémato après. Fidélité : 9 à 9,75/10. Deux petites erreurs seulement : item 226, fiche ECG « V1 à V4 » alors que le texte dit « V1 à V3 » coupé sur deux lignes ; item 75, une précision non sourcée. Aucune fiche hors sujet. Le découpage est exact sur 65/65 items. Défaut principal : 14 items dépassent 40 fiches (213 : 56, 216 : 53, 329 : 51). Claude rédige dans l'ordre du texte et claude_client garde les 40 premières, donc les sections de fin, y compris du rang A, sont perdues : hémophilie en 216, volet pédiatrique en 220, hémovigilance en 329. Correctif sans coût proposé : tronquer le rang B avant le rang A. Défauts de forme restants : environ 10 % de versos en liste de 6 éléments ou plus, environ 65 questions composées « X et Y ? ». Coût réel : environ 4,80 € pour les 3 collèges.\nEvidence: Export prod item_generations claude-sonnet-5:p2 ; 3 revues par collège ; logs worker « Item N : X fiches, tronqué à 40 » ; texte item 226 ligne « onde T négative de V1 à / V3 »","verification":"Export prod item_generations claude-sonnet-5:p2 ; 3 revues par collège ; logs worker « Item N : X fiches, tronqué à 40 » ; texte item 226 ligne « onde T négative de V1 à / V3 »"},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-25T08:58:51.254Z","path_fingerprints":[{"path":"collega_backend/app/services/generation/claude_client.py","sha256":"7268b74431df8a133831160c37abbd7e225ced6f929e0fff3f8b9156ec715181","size":15299},{"path":"_bmad-output/planning-artifacts/chantier-4-couts-claude-spec.md","sha256":"ee1877d51bacec08937f8e062f306df8250304853a7ffb5b0222b4633f1bfc2a","size":17874}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":4000,"discovery_tokens_estimated":true,"score":94,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":296,"total_uses":0},"created_at":"2026-09-25T08:58:51.254Z","updated_at":"2026-09-25T08:58:51.254Z","author_branch":"feat/refonte-back-infra"}
```

