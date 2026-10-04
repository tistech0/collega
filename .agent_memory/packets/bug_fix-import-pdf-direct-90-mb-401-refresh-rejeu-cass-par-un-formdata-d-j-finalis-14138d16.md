---
type: "Bug Fix"
title: "Import PDF direct (< 90 MB) : 401 → refresh → rejeu cassé par un FormData déjà finalisé"
description: "Symptôme 2026 10 03, testeuse : « erreur de connexion » à l'import d'un collège. Les logs API montrent POST /v1/colleges/{id}/import → 401 puis POST /v1/auth/refresh → 200 et AUCUN rejeu. Cause : l'access token expire ap"
resource: "collega_app/lib/core/network/api_client.dart"
tags: ["session-learning", "upload", "import", "auth", "refresh", "dio", "formdata"]
timestamp: "2026-10-04T10:08:10.387Z"
x-kage-id: "repo:git-github-com-tistech0-collega:bug_fix:import-pdf-direct-90-mb-401-refresh-rejeu-cass-par-un-formdata-d-j-finalis-17911"
x-kage-type: "bug_fix"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_app/lib/core/network/api_client.dart", "collega_app/test/core/network/api_client_test.dart", "collega_app/lib/features/colleges/data/college_import_repository.dart"]
---

# Import PDF direct (< 90 MB) : 401 → refresh → rejeu cassé par un FormData déjà finalisé

> Symptôme 2026 10 03, testeuse : « erreur de connexion » à l'import d'un collège. Les logs API montrent POST /v1/colle…

Symptôme (2026-10-03, testeuse) : « erreur de connexion » à l'import d'un collège. Les logs API montrent POST /v1/colleges/{id}/import → 401 puis POST /v1/auth/refresh → 200 et AUCUN rejeu. Cause : l'access token expire après inactivité ; l'intercepteur 401 de ApiClient rejouait error.requestOptions tel quel, mais un FormData Dio ne s'envoie qu'une fois (« The FormData has already been finalized ») → DioException unknown → ImportError réseau. Pas lié au patch PDF 343c1d8 : le bug existait depuis que l'import direct passe par l'intercepteur ; il se déclenche dès que l'import est la première requête après expiration du token. Correctif : cloner le FormData (FormData.clone()) avant le rejeu dans l'intercepteur. Pour diagnostiquer : docker logs collega-api-1 sur le NAS et chercher le couple 401 + refresh sans rejeu.
Evidence: Test 'POST FormData : 401 → refresh → rejeu avec le corps complet' échouait avec l'erreur exacte, passe après le clone ; test/core (551) et test/features/colleges (270) verts.

## Verification

Test 'POST FormData : 401 → refresh → rejeu avec le corps complet' échouait avec l'erreur exacte, passe après le clone ; test/core (551) et test/features/colleges (270) verts.

# Citations

[1] explicit_capture (2026-10-04T10:08:10.387Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:bug_fix:import-pdf-direct-90-mb-401-refresh-rejeu-cass-par-un-formdata-d-j-finalis-17911","title":"Import PDF direct (< 90 MB) : 401 → refresh → rejeu cassé par un FormData déjà finalisé","summary":"Symptôme 2026 10 03, testeuse : « erreur de connexion » à l'import d'un collège. Les logs API montrent POST /v1/colleges/{id}/import → 401 puis POST /v1/auth/refresh → 200 et AUCUN rejeu. Cause : l'access token expire ap","body":"Symptôme (2026-10-03, testeuse) : « erreur de connexion » à l'import d'un collège. Les logs API montrent POST /v1/colleges/{id}/import → 401 puis POST /v1/auth/refresh → 200 et AUCUN rejeu. Cause : l'access token expire après inactivité ; l'intercepteur 401 de ApiClient rejouait error.requestOptions tel quel, mais un FormData Dio ne s'envoie qu'une fois (« The FormData has already been finalized ») → DioException unknown → ImportError réseau. Pas lié au patch PDF 343c1d8 : le bug existait depuis que l'import direct passe par l'intercepteur ; il se déclenche dès que l'import est la première requête après expiration du token. Correctif : cloner le FormData (FormData.clone()) avant le rejeu dans l'intercepteur. Pour diagnostiquer : docker logs collega-api-1 sur le NAS et chercher le couple 401 + refresh sans rejeu.\nEvidence: Test 'POST FormData : 401 → refresh → rejeu avec le corps complet' échouait avec l'erreur exacte, passe après le clone ; test/core (551) et test/features/colleges (270) verts.","type":"bug_fix","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","upload","import","auth","refresh","dio","formdata"],"paths":["collega_app/lib/core/network/api_client.dart","collega_app/test/core/network/api_client_test.dart","collega_app/lib/features/colleges/data/college_import_repository.dart"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-10-04T10:08:10.387Z"}],"context":{"fact":"Symptôme (2026-10-03, testeuse) : « erreur de connexion » à l'import d'un collège. Les logs API montrent POST /v1/colleges/{id}/import → 401 puis POST /v1/auth/refresh → 200 et AUCUN rejeu. Cause : l'access token expire après inactivité ; l'intercepteur 401 de ApiClient rejouait error.requestOptions tel quel, mais un FormData Dio ne s'envoie qu'une fois (« The FormData has already been finalized ») → DioException unknown → ImportError réseau. Pas lié au patch PDF 343c1d8 : le bug existait depuis que l'import direct passe par l'intercepteur ; il se déclenche dès que l'import est la première requête après expiration du token. Correctif : cloner le FormData (FormData.clone()) avant le rejeu dans l'intercepteur. Pour diagnostiquer : docker logs collega-api-1 sur le NAS et chercher le couple 401 + refresh sans rejeu.\nEvidence: Test 'POST FormData : 401 → refresh → rejeu avec le corps complet' échouait avec l'erreur exacte, passe après le clone ; test/core (551) et test/features/colleges (270) verts.","verification":"Test 'POST FormData : 401 → refresh → rejeu avec le corps complet' échouait avec l'erreur exacte, passe après le clone ; test/core (551) et test/features/colleges (270) verts."},"freshness":{"ttl_days":365,"last_verified_at":"2026-10-04T10:08:10.387Z","path_fingerprints":[{"path":"collega_app/lib/core/network/api_client.dart","sha256":"c754b19fdc6910d34c93b4edb247ab7a6df0a35eaf2a1f6950541c5eebd5a9cf","size":7687},{"path":"collega_app/test/core/network/api_client_test.dart","sha256":"3343368ff68152fbf90139f3a743f8db172a1058f3670f67d69b7f5551e97ce4","size":12501},{"path":"collega_app/lib/features/colleges/data/college_import_repository.dart","sha256":"5894a50f348353a89fec62cffb6a71b33fedc1df979ab9412cafc5447c5d28f1","size":2646}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":8000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"stale_reasons":[],"estimated_tokens_saved":253},"created_at":"2026-10-04T10:08:10.387Z","updated_at":"2026-10-04T10:08:10.387Z","author_branch":"main"}
```

