---
type: "Gotcha"
title: "CI illisible depuis ce Mac (gh = CrazyGrower) : la rejouer en local avec act et le conteneur Flutter"
description: "gh local est connecté au compte CrazyGrower qui ne voit pas le dépôt privé tistech0/collega push SSH en tistech0 : gh run list → 404, donc deploy.sh demande force . Pour vérifier la CI avant de déployer : job backend ave"
resource: ".github/workflows/ci.yml"
tags: ["session-learning", "ci", "act", "flutter", "goldens", "gh"]
timestamp: "2026-09-24T18:18:07.154Z"
x-kage-id: "repo:git-github-com-tistech0-collega:gotcha:ci-illisible-depuis-ce-mac-gh-crazygrower-la-rejouer-en-local-avec-act-et-le-con"
x-kage-type: "gotcha"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: [".github/workflows/ci.yml", "collega_app/dart_test.yaml", "collega_backend/docs/testing.md"]
---

# CI illisible depuis ce Mac (gh = CrazyGrower) : la rejouer en local avec act et le conteneur Flutter

> gh local est connecté au compte CrazyGrower qui ne voit pas le dépôt privé tistech0/collega push SSH en tistech0 : gh…

`gh` local est connecté au compte CrazyGrower qui ne voit pas le dépôt privé tistech0/collega (push SSH en tistech0) : `gh run list` → 404, donc deploy.sh demande `--force`. Pour vérifier la CI avant de déployer : job backend avec `act push -j backend -P ubuntu-latest=catthehacker/ubuntu:act-latest --container-architecture linux/arm64 --pull=false` (arrêter d'abord docker-compose.test.yml, mêmes ports 55432/56379 ; en amd64 l'image act de 1,6 Go se retélécharge et act reste bloqué au pull) ; job app : subosito/flutter-action ne gère pas arm64, donc extraire les `run:` du job app de ci.yml et les exécuter dans `docker run --rm -v <copie git archive>:/src ghcr.io/cirruslabs/flutter:3.27.1 bash /src/run.sh`. Sous Linux, les goldens (rendu du texte, 2-4 % de pixels) et les tests de contraste mesuré sur l'image échouent : ils portent le tag `golden` (collega_app/dart_test.yaml) et la CI passe `--exclude-tags golden` ; ils restent à lancer en local sur macOS.
Evidence: 2026-09-24 : act backend vert (552 tests, alembic check) ; conteneur Flutter : 13 dossiers verts après exclusion des 314 goldens.

## Verification

2026-09-24 : act backend vert (552 tests, alembic check) ; conteneur Flutter : 13 dossiers verts après exclusion des 314 goldens.

# Citations

[1] explicit_capture (2026-09-24T18:18:07.154Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:gotcha:ci-illisible-depuis-ce-mac-gh-crazygrower-la-rejouer-en-local-avec-act-et-le-con","title":"CI illisible depuis ce Mac (gh = CrazyGrower) : la rejouer en local avec act et le conteneur Flutter","summary":"gh local est connecté au compte CrazyGrower qui ne voit pas le dépôt privé tistech0/collega push SSH en tistech0 : gh run list → 404, donc deploy.sh demande force . Pour vérifier la CI avant de déployer : job backend ave","body":"`gh` local est connecté au compte CrazyGrower qui ne voit pas le dépôt privé tistech0/collega (push SSH en tistech0) : `gh run list` → 404, donc deploy.sh demande `--force`. Pour vérifier la CI avant de déployer : job backend avec `act push -j backend -P ubuntu-latest=catthehacker/ubuntu:act-latest --container-architecture linux/arm64 --pull=false` (arrêter d'abord docker-compose.test.yml, mêmes ports 55432/56379 ; en amd64 l'image act de 1,6 Go se retélécharge et act reste bloqué au pull) ; job app : subosito/flutter-action ne gère pas arm64, donc extraire les `run:` du job app de ci.yml et les exécuter dans `docker run --rm -v <copie git archive>:/src ghcr.io/cirruslabs/flutter:3.27.1 bash /src/run.sh`. Sous Linux, les goldens (rendu du texte, 2-4 % de pixels) et les tests de contraste mesuré sur l'image échouent : ils portent le tag `golden` (collega_app/dart_test.yaml) et la CI passe `--exclude-tags golden` ; ils restent à lancer en local sur macOS.\nEvidence: 2026-09-24 : act backend vert (552 tests, alembic check) ; conteneur Flutter : 13 dossiers verts après exclusion des 314 goldens.","type":"gotcha","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","ci","act","flutter","goldens","gh"],"paths":[".github/workflows/ci.yml","collega_app/dart_test.yaml","collega_backend/docs/testing.md"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-24T18:18:07.154Z"}],"context":{"fact":"`gh` local est connecté au compte CrazyGrower qui ne voit pas le dépôt privé tistech0/collega (push SSH en tistech0) : `gh run list` → 404, donc deploy.sh demande `--force`. Pour vérifier la CI avant de déployer : job backend avec `act push -j backend -P ubuntu-latest=catthehacker/ubuntu:act-latest --container-architecture linux/arm64 --pull=false` (arrêter d'abord docker-compose.test.yml, mêmes ports 55432/56379 ; en amd64 l'image act de 1,6 Go se retélécharge et act reste bloqué au pull) ; job app : subosito/flutter-action ne gère pas arm64, donc extraire les `run:` du job app de ci.yml et les exécuter dans `docker run --rm -v <copie git archive>:/src ghcr.io/cirruslabs/flutter:3.27.1 bash /src/run.sh`. Sous Linux, les goldens (rendu du texte, 2-4 % de pixels) et les tests de contraste mesuré sur l'image échouent : ils portent le tag `golden` (collega_app/dart_test.yaml) et la CI passe `--exclude-tags golden` ; ils restent à lancer en local sur macOS.\nEvidence: 2026-09-24 : act backend vert (552 tests, alembic check) ; conteneur Flutter : 13 dossiers verts après exclusion des 314 goldens.","verification":"2026-09-24 : act backend vert (552 tests, alembic check) ; conteneur Flutter : 13 dossiers verts après exclusion des 314 goldens."},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-24T18:18:07.154Z","path_fingerprints":[{"path":".github/workflows/ci.yml","sha256":"52f446af3054494c35422d416296dbb5a4935f6786b7ffea45cb8a27d011a9b1","size":4336},{"path":"collega_app/dart_test.yaml","sha256":"9ab3b2fd5f31a5b4ba8274857fed9eaf05196d707e24aff27d1a6cd174d30469","size":200},{"path":"collega_backend/docs/testing.md","sha256":"9313869a5539aaefc465ff58dd7bf50dd8a44c6b00d071d4d8b71482a642727c","size":1880}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":14,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":8000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":277,"total_uses":14,"last_accessed_at":"2026-09-26T14:51:21.857Z"},"created_at":"2026-09-24T18:18:07.154Z","updated_at":"2026-09-24T18:18:07.154Z","author_branch":"feat/refonte-back-infra"}
```

