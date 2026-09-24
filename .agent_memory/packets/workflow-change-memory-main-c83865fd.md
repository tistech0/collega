---
type: "Workflow"
title: "Change memory: main"
description: "Repo-local context for 2 changed repo paths on main."
resource: "_bmad-output/planning-artifacts/chantier-2-securite-spec.md"
tags: ["change-memory", "diff-proposal", "repo-local", "branch:main"]
timestamp: "2026-09-24T16:51:21.611Z"
x-kage-id: "repo:git-github-com-tistech0-collega:workflow:change-memory-main"
x-kage-type: "workflow"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "verified"
x-kage-paths: ["_bmad-output/planning-artifacts/chantier-2-securite-spec.md", "_bmad-output/planning-artifacts/chantier-3-outillage-dev-spec.md"]
---

# Change memory: main

> Repo-local context for 2 changed repo paths on main.

Repo-local change memory generated from the current git diff.

Goal: preserve the durable context another agent should receive when it works in this repo later.

What changed:
- _bmad-output/planning-artifacts/chantier-2-securite-spec.md
- _bmad-output/planning-artifacts/chantier-3-outillage-dev-spec.md

Diff summary:
```text
...-status-n-tait-jamais-avanc-generation-complete-job-seulement-import-jama-5ea68aac.md |  2 +-
 ...e-progression-empil-s-un-push-par-tat-importstreaming-rafales-status-n-st-c3e6a84b.md |  2 +-
 ...timeout-coll-ge-vide-sse-coup-par-cloudflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md |  2 +-
 .../packets/convention-docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-0f0a3cd4.md   |  2 +-
 .../packets/convention-docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-746ea530.md   |  2 +-
 .agent_memory/packets/convention-rate-limit-login-5-min-via-slowapi-redis-7e992825.md    |  2 +-
 .agent_memory/packets/convention-rate-limit-login-5-min-via-slowapi-redis-d99fb98f.md    |  2 +-
 ...ackend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md |  2 +-
 ...ne-fiche-revoir-nest-r-ins-r-e-quune-fois-toast-2-s-la-2e-fois-elle-est-c-2cdcd000.md |  2 +-
 ...decision-import-avancement-de-g-n-ration-migrations-016-017-et-crans-8-13-7d46adce.md |  2 +-
 ...avancement-de-g-n-ration-n-fiches-pr-tes-8-13-publi-item-par-item-par-le--859a91a7.md |  2 +-
 ...e-dimport-chantier-1-apr-s-revue-empreintes-par-page-items-inchang-s-jama-4db54e68.md |  2 +-
 ...e-dimport-chantier-1-contenu-par-empreinte-brouillon-puis-bascule-statut--654af2eb.md |  2 +-
 .../decision-planning-v2-8-9-et-journal-complet-des-r-visions-8-8-sch-ma-v8-aae5950d.md  |  2 +-
 ...tiel-item-titles-titres-ditems-partag-s-entre-coll-ges-official-plus-fr-q-b8a67ce6.md |  2 +-
 ...-ux-ui-v2-direction-feuille
… [+2325 chars truncated]
```

How to verify:
- Add the exact test, build, or manual verification command when you refine this memory.

Improve this packet when more context is known:
- The actual feature, fix, or refactor rationale.
- Why the change was made, including relevant bugs, issues, decisions, and code explanations.
- The package, API, command, or architectural pattern future agents should understand, verify, or reuse.
- Any gotchas, follow-up risks, or branch-specific assumptions.

Promote beyond this repo only after explicit org/global review.

## Why

Branch change memory gives future agents durable context from the git diff when they continue, review, or verify this work.

## Trigger

Recall when asking what changed on this branch, preparing a PR review, or resuming this work.

## Action

Use the changed file list and diff summary as orientation, then inspect the actual diff and source files before making further edits.

## Verification

Generated from git diff and refreshed by kage pr summarize or kage propose --from-diff.

## Risk if forgotten

Future agents may repeat orientation work, miss branch-specific assumptions, or ignore files touched by this change.

## Stale when

The branch diff changes substantially, the branch is merged, or a newer change-memory packet supersedes it.

# Citations

[1] git_diff

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:workflow:change-memory-main","title":"Change memory: main","summary":"Repo-local context for 2 changed repo paths on main.","body":"Repo-local change memory generated from the current git diff.\n\nGoal: preserve the durable context another agent should receive when it works in this repo later.\n\nWhat changed:\n- _bmad-output/planning-artifacts/chantier-2-securite-spec.md\n- _bmad-output/planning-artifacts/chantier-3-outillage-dev-spec.md\n\nDiff summary:\n```text\n...-status-n-tait-jamais-avanc-generation-complete-job-seulement-import-jama-5ea68aac.md |  2 +-\n ...e-progression-empil-s-un-push-par-tat-importstreaming-rafales-status-n-st-c3e6a84b.md |  2 +-\n ...timeout-coll-ge-vide-sse-coup-par-cloudflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md |  2 +-\n .../packets/convention-docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-0f0a3cd4.md   |  2 +-\n .../packets/convention-docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-746ea530.md   |  2 +-\n .agent_memory/packets/convention-rate-limit-login-5-min-via-slowapi-redis-7e992825.md    |  2 +-\n .agent_memory/packets/convention-rate-limit-login-5-min-via-slowapi-redis-d99fb98f.md    |  2 +-\n ...ackend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md |  2 +-\n ...ne-fiche-revoir-nest-r-ins-r-e-quune-fois-toast-2-s-la-2e-fois-elle-est-c-2cdcd000.md |  2 +-\n ...decision-import-avancement-de-g-n-ration-migrations-016-017-et-crans-8-13-7d46adce.md |  2 +-\n ...avancement-de-g-n-ration-n-fiches-pr-tes-8-13-publi-item-par-item-par-le--859a91a7.md |  2 +-\n ...e-dimport-chantier-1-apr-s-revue-empreintes-par-page-items-inchang-s-jama-4db54e68.md |  2 +-\n ...e-dimport-chantier-1-contenu-par-empreinte-brouillon-puis-bascule-statut--654af2eb.md |  2 +-\n .../decision-planning-v2-8-9-et-journal-complet-des-r-visions-8-8-sch-ma-v8-aae5950d.md  |  2 +-\n ...tiel-item-titles-titres-ditems-partag-s-entre-coll-ges-official-plus-fr-q-b8a67ce6.md |  2 +-\n ...-ux-ui-v2-direction-feuille\n… [+2325 chars truncated]\n```\n\nHow to verify:\n- Add the exact test, build, or manual verification command when you refine this memory.\n\nImprove this packet when more context is known:\n- The actual feature, fix, or refactor rationale.\n- Why the change was made, including relevant bugs, issues, decisions, and code explanations.\n- The package, API, command, or architectural pattern future agents should understand, verify, or reuse.\n- Any gotchas, follow-up risks, or branch-specific assumptions.\n\nPromote beyond this repo only after explicit org/global review.","type":"workflow","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.62,"tags":["change-memory","diff-proposal","repo-local","branch:main"],"paths":["_bmad-output/planning-artifacts/chantier-2-securite-spec.md","_bmad-output/planning-artifacts/chantier-3-outillage-dev-spec.md"],"stack":[],"source_refs":[{"kind":"git_diff","branch":"main","head":"0e6a28dee59e846030b347d3480ccf2b6cbe47a8","merge_base":"0e6a28dee59e846030b347d3480ccf2b6cbe47a8","changed_files":[".agent_memory/packets/bug_fix-college-status-n-tait-jamais-avanc-generation-complete-job-seulement-import-jama-5ea68aac.md",".agent_memory/packets/bug_fix-crans-de-progression-empil-s-un-push-par-tat-importstreaming-rafales-status-n-st-c3e6a84b.md",".agent_memory/packets/bug_fix-import-timeout-coll-ge-vide-sse-coup-par-cloudflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md",".agent_memory/packets/convention-docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-0f0a3cd4.md",".agent_memory/packets/convention-docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-746ea530.md",".agent_memory/packets/convention-rate-limit-login-5-min-via-slowapi-redis-7e992825.md",".agent_memory/packets/convention-rate-limit-login-5-min-via-slowapi-redis-d99fb98f.md",".agent_memory/packets/decision-acc-s-backend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md",".agent_memory/packets/decision-drill-une-fiche-revoir-nest-r-ins-r-e-quune-fois-toast-2-s-la-2e-fois-elle-est-c-2cdcd000.md",".agent_memory/packets/decision-import-avancement-de-g-n-ration-migrations-016-017-et-crans-8-13-7d46adce.md",".agent_memory/packets/decision-import-avancement-de-g-n-ration-n-fiches-pr-tes-8-13-publi-item-par-item-par-le--859a91a7.md",".agent_memory/packets/decision-pipeline-dimport-chantier-1-apr-s-revue-empreintes-par-page-items-inchang-s-jama-4db54e68.md",".agent_memory/packets/decision-pipeline-dimport-chantier-1-contenu-par-empreinte-brouillon-puis-bascule-statut--654af2eb.md",".agent_memory/packets/decision-planning-v2-8-9-et-journal-complet-des-r-visions-8-8-sch-ma-v8-aae5950d.md",".agent_memory/packets/decision-r-f-rentiel-item-titles-titres-ditems-partag-s-entre-coll-ges-official-plus-fr-q-b8a67ce6.md",".agent_memory/packets/decision-refonte-ux-ui-v2-direction-feuille-bloc-collega-ui-epic-8-r-f-rentiel-de-titres--752f4a56.md",".agent_memory/packets/decision-refonte-ux-ui-v2-direction-feuille-bloc-design-system-maison-collega-ui-epic-8-06e10ce8.md",".agent_memory/packets/decision-session-du-jour-8-3-moteur-persistance-locale-synchro-des-fiches-un-r-import-ne--26c31dc9.md",".agent_memory/packets/decision-session-du-jour-8-3-moteur-persistance-synchro-des-fiches-propri-taire-des-donn--ab467dbd.md",".agent_memory/packets/decision-upload-par-morceaux-story-7-11-architecture-backend-init-parts-complete-helpers--6eee8fc0.md",".agent_memory/packets/gotcha-app-upload-par-morceaux-chunkeduploadservice-background-downloader-9-5-5-pi-ges--83a931c5.md",".agent_memory/packets/gotcha-collega-ui-police-embarqu-e-goldens-widgetbook-web-contrastes-jour-8-15-faf0c765.md",".agent_memory/packets/gotcha-formats-r-els-des-pdf-de-coll-ges-cep-cnec-pi-ges-de-litemdetector-et-o-relire-l-46d17c50.md",".agent_memory/packets/gotcha-formats-r-els-des-pdf-de-coll-ges-en-t-tes-courants-cnec-objectifs-n-sommaire-le-6573083c.md",".agent_memory/packets/gotcha-prod-collegatest-2-chemins-r-seau-le-chemin-public-est-bloqu-par-cloudflare-acce-4c9884ac.md",".agent_memory/packets/gotcha-profil-me-rappel-quotidien-et-quota-pi-ges-8-14-b70b1768.md",".agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md",".agent_memory/packets/repo_map-collega-repo-structure-0317f7c1.md",".agent_memory/packets/runbook-d-ployer-le-backend-collega-sur-le-nas-build-amd64-push-docker-hub-compose-pull--34a7927b.md",".agent_memory/packets/runbook-logo-collega-source-unique-et-r-g-n-ration-de-lic-ne-ios-6d6845d3.md",".agent_memory/packets/runbook-restauration-collega-prouv-e-dump-pg-dumpall-nocturne-2-erreurs-de-rejeu-normale-821d10ee.md",".agent_memory/packets/runbook-supervision-collega-health-alertes-panne-et-retour-en-niveau-alert-lagent-telegr-a8d5f36f.md",".agent_memory/packets/workflow-change-memory-main-c83865fd.md",".agent_memory/packets/workflow-story-7-11-d-ploy-e-et-v-rifi-e-en-prod-wi-fi-cancero-411-mb-en-17-morceaux-177--8ba9bed7.md","_bmad-output/planning-artifacts/chantier-2-securite-spec.md","_bmad-output/planning-artifacts/chantier-3-outillage-dev-spec.md"],"summary_path":"/Users/lesurmatthis/dev/projet perso/collega/.agent_memory/review/branch-summary-main.json"}],"context":{"fact":"Current branch main changes 2 repo paths.","why":"Branch change memory gives future agents durable context from the git diff when they continue, review, or verify this work.","trigger":"Recall when asking what changed on this branch, preparing a PR review, or resuming this work.","action":"Use the changed file list and diff summary as orientation, then inspect the actual diff and source files before making further edits.","verification":"Generated from git diff and refreshed by kage pr summarize or kage propose --from-diff.","risk_if_forgotten":"Future agents may repeat orientation work, miss branch-specific assumptions, or ignore files touched by this change.","stale_when":"The branch diff changes substantially, the branch is merged, or a newer change-memory packet supersedes it."},"freshness":{"last_verified_at":"2026-09-24T16:51:21.611Z","ttl_days":180,"path_fingerprints":[{"path":"_bmad-output/planning-artifacts/chantier-2-securite-spec.md","sha256":"8e33f59e5f739c976d332f00c2d287a69e193386fef686b86d7770a571fde250","size":8049},{"path":"_bmad-output/planning-artifacts/chantier-3-outillage-dev-spec.md","sha256":"422c16a20713888edf819997ac98df1b387b3f39c525f23bbca9603dd96a08db","size":6652}],"path_fingerprint_policy":"source_hash_staleness","verification":"git_diff"},"edges":[{"relation":"changes_path","to":"path:.agent_memory/packets/bug_fix-college-status-n-tait-jamais-avanc-generation-complete-job-seulement-import-jama-5ea68aac.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/bug_fix-crans-de-progression-empil-s-un-push-par-tat-importstreaming-rafales-status-n-st-c3e6a84b.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/bug_fix-import-timeout-coll-ge-vide-sse-coup-par-cloudflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/convention-docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-0f0a3cd4.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/convention-docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-746ea530.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/convention-rate-limit-login-5-min-via-slowapi-redis-7e992825.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/convention-rate-limit-login-5-min-via-slowapi-redis-d99fb98f.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-acc-s-backend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-drill-une-fiche-revoir-nest-r-ins-r-e-quune-fois-toast-2-s-la-2e-fois-elle-est-c-2cdcd000.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-import-avancement-de-g-n-ration-migrations-016-017-et-crans-8-13-7d46adce.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-import-avancement-de-g-n-ration-n-fiches-pr-tes-8-13-publi-item-par-item-par-le--859a91a7.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-pipeline-dimport-chantier-1-apr-s-revue-empreintes-par-page-items-inchang-s-jama-4db54e68.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-pipeline-dimport-chantier-1-contenu-par-empreinte-brouillon-puis-bascule-statut--654af2eb.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-planning-v2-8-9-et-journal-complet-des-r-visions-8-8-sch-ma-v8-aae5950d.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-r-f-rentiel-item-titles-titres-ditems-partag-s-entre-coll-ges-official-plus-fr-q-b8a67ce6.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-refonte-ux-ui-v2-direction-feuille-bloc-collega-ui-epic-8-r-f-rentiel-de-titres--752f4a56.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-refonte-ux-ui-v2-direction-feuille-bloc-design-system-maison-collega-ui-epic-8-06e10ce8.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-session-du-jour-8-3-moteur-persistance-locale-synchro-des-fiches-un-r-import-ne--26c31dc9.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-session-du-jour-8-3-moteur-persistance-synchro-des-fiches-propri-taire-des-donn--ab467dbd.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-upload-par-morceaux-story-7-11-architecture-backend-init-parts-complete-helpers--6eee8fc0.md","evidence":"git_diff"}],"quality":{"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"stale_reasons":[],"estimated_tokens_saved":598,"admission":{"admit":true,"class":"candidate","score":70,"reasons":["durable memory type","has provenance","repo scoped or path grounded","has durable trigger, rationale, issue context, or explanation","substantive enough to reuse"],"risks":[]},"candidate_kind":"change_memory","review_boundary":"git_or_pr","promotion_requires_review":true},"created_at":"2026-09-24T16:51:21.611Z","updated_at":"2026-09-24T16:51:21.611Z"}
```

