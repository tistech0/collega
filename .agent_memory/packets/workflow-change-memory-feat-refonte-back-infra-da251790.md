---
type: "Workflow"
title: "Change memory: feat/refonte-back-infra"
description: "Repo-local context for 1 changed repo path on feat/refonte-back-infra."
resource: ".DS_Store"
tags: ["change-memory", "diff-proposal", "repo-local", "branch:feat-refonte-back-infra"]
timestamp: "2026-09-24T22:04:42.196Z"
x-kage-id: "repo:git-github-com-tistech0-collega:workflow:change-memory-feat-refonte-back-infra"
x-kage-type: "workflow"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "verified"
x-kage-paths: [".DS_Store"]
---

# Change memory: feat/refonte-back-infra

> Repo-local context for 1 changed repo path on feat/refonte-back-infra.

Repo-local change memory generated from the current git diff.

Goal: preserve the durable context another agent should receive when it works in this repo later.

What changed:
- .DS_Store

Diff summary:
```text
.agent_memory/audit/events.jsonl                   | 15 +++++
 ...importstreaming-rafales-status-n-st-c3e6a84b.md | 11 +++-
 ...dflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md |  8 ++-
 ...-sormais-toutes-synchronis-es-8-3-l-c6a82ada.md |  7 +-
 ...n-5-min-par-ip-et-limites-par-route-ad092c92.md | 12 ++--
 ...n-en-prod-d-sactiv-s-post-v1-auth-r-0c4f0781.md | 12 +++-
 ...oken-dans-lapp-heartbeat-sse-limite-4e3de494.md | 14 +++-
 ...ois-toast-2-s-la-2e-fois-elle-est-c-2cdcd000.md |  7 +-
 ...es-8-13-publi-item-par-item-par-le--859a91a7.md | 11 +++-
 ...intes-par-page-items-inchang-s-jama-4db54e68.md |  8 ++-
 ...s-entre-coll-ges-official-plus-fr-q-b8a67ce6.md |  6 +-
 ...ga-ui-epic-8-r-f-rentiel-de-titres--752f4a56.md |  6 +-
 ...plan-chantier-4-d-ploiement-continu-671f678e.md |  9 ++-
 ...-synchro-des-fiches-un-r-import-ne--26c31dc9.md |  6 +-
 ...ackend-init-parts-complete-helpers--6eee8fc0.md | 16 +++--
 ...background-downloader-9-5-5-pi-ges--83a931c5.md |  5 +-
 ...blage-des-composants-pour-les-crans-f3c8b7d2.md |  7 +-
 ...widgetbook-web-contrastes-jour-8-15-faf0c765.md |  5 +-
 ...-ges-de-litemdetector-et-o-relire-l-46d17c50.md |  9 +--
 ...ublic-est-bloqu-par-cloudflare-acce-4c9884ac.md |  6 +-
 ...ppel-quotidien-et-quota-pi-ges-8-14-2d47f0a8.md |  8 ++-
 ...jamais-lu-en-debug-il-se-construit--3de106de.md |  6 +-
 ...jamais-le-recr-er-sur-un-changement-4f6c8dc1.md |  5 +-
 ...-ferme-pas-recherche-sheet-extrait--74575541.md |  6 +-
 ...l-les-tests-home-ont-disparu-en-8-3-
… [+1683 chars truncated]
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
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:workflow:change-memory-feat-refonte-back-infra","title":"Change memory: feat/refonte-back-infra","summary":"Repo-local context for 1 changed repo path on feat/refonte-back-infra.","body":"Repo-local change memory generated from the current git diff.\n\nGoal: preserve the durable context another agent should receive when it works in this repo later.\n\nWhat changed:\n- .DS_Store\n\nDiff summary:\n```text\n.agent_memory/audit/events.jsonl                   | 15 +++++\n ...importstreaming-rafales-status-n-st-c3e6a84b.md | 11 +++-\n ...dflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md |  8 ++-\n ...-sormais-toutes-synchronis-es-8-3-l-c6a82ada.md |  7 +-\n ...n-5-min-par-ip-et-limites-par-route-ad092c92.md | 12 ++--\n ...n-en-prod-d-sactiv-s-post-v1-auth-r-0c4f0781.md | 12 +++-\n ...oken-dans-lapp-heartbeat-sse-limite-4e3de494.md | 14 +++-\n ...ois-toast-2-s-la-2e-fois-elle-est-c-2cdcd000.md |  7 +-\n ...es-8-13-publi-item-par-item-par-le--859a91a7.md | 11 +++-\n ...intes-par-page-items-inchang-s-jama-4db54e68.md |  8 ++-\n ...s-entre-coll-ges-official-plus-fr-q-b8a67ce6.md |  6 +-\n ...ga-ui-epic-8-r-f-rentiel-de-titres--752f4a56.md |  6 +-\n ...plan-chantier-4-d-ploiement-continu-671f678e.md |  9 ++-\n ...-synchro-des-fiches-un-r-import-ne--26c31dc9.md |  6 +-\n ...ackend-init-parts-complete-helpers--6eee8fc0.md | 16 +++--\n ...background-downloader-9-5-5-pi-ges--83a931c5.md |  5 +-\n ...blage-des-composants-pour-les-crans-f3c8b7d2.md |  7 +-\n ...widgetbook-web-contrastes-jour-8-15-faf0c765.md |  5 +-\n ...-ges-de-litemdetector-et-o-relire-l-46d17c50.md |  9 +--\n ...ublic-est-bloqu-par-cloudflare-acce-4c9884ac.md |  6 +-\n ...ppel-quotidien-et-quota-pi-ges-8-14-2d47f0a8.md |  8 ++-\n ...jamais-lu-en-debug-il-se-construit--3de106de.md |  6 +-\n ...jamais-le-recr-er-sur-un-changement-4f6c8dc1.md |  5 +-\n ...-ferme-pas-recherche-sheet-extrait--74575541.md |  6 +-\n ...l-les-tests-home-ont-disparu-en-8-3-\n… [+1683 chars truncated]\n```\n\nHow to verify:\n- Add the exact test, build, or manual verification command when you refine this memory.\n\nImprove this packet when more context is known:\n- The actual feature, fix, or refactor rationale.\n- Why the change was made, including relevant bugs, issues, decisions, and code explanations.\n- The package, API, command, or architectural pattern future agents should understand, verify, or reuse.\n- Any gotchas, follow-up risks, or branch-specific assumptions.\n\nPromote beyond this repo only after explicit org/global review.","type":"workflow","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.62,"tags":["change-memory","diff-proposal","repo-local","branch:feat-refonte-back-infra"],"paths":[".DS_Store"],"stack":[],"source_refs":[{"kind":"git_diff","branch":"feat/refonte-back-infra","head":"18fcb1f12b239bd0464b030b06af95352b88492b","merge_base":"0e6a28dee59e846030b347d3480ccf2b6cbe47a8","changed_files":[".DS_Store",".agent_memory/packets/bug_fix-crans-de-progression-empil-s-un-push-par-tat-importstreaming-rafales-status-n-st-c3e6a84b.md",".agent_memory/packets/bug_fix-import-timeout-coll-ge-vide-sse-coup-par-cloudflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md",".agent_memory/packets/bug_fix-progression-coll-ge-les-fiches-locales-sont-d-sormais-toutes-synchronis-es-8-3-l-c6a82ada.md",".agent_memory/packets/convention-backend-apr-s-chantier-5-routes-par-domaine-apperror-pool-arq-du-lifespan-servic-ec008ce5.md",".agent_memory/packets/convention-rate-limit-slowapi-redis-login-5-min-par-ip-et-limites-par-route-ad092c92.md",".agent_memory/packets/convention-surface-api-r-duite-docs-redoc-et-openapi-json-en-prod-d-sactiv-s-post-v1-auth-r-0c4f0781.md",".agent_memory/packets/decision-acc-s-backend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md",".agent_memory/packets/decision-drill-une-fiche-revoir-nest-r-ins-r-e-quune-fois-toast-2-s-la-2e-fois-elle-est-c-2cdcd000.md",".agent_memory/packets/decision-g-n-ration-des-fiches-apr-s-chantier-4-d-coupage-r0-r10-prompt-p2-sonnet-5-claud-9dc1ef95.md",".agent_memory/packets/decision-import-avancement-de-g-n-ration-n-fiches-pr-tes-8-13-publi-item-par-item-par-le--859a91a7.md",".agent_memory/packets/decision-pipeline-dimport-chantier-1-apr-s-revue-empreintes-par-page-items-inchang-s-jama-4db54e68.md",".agent_memory/packets/decision-r-f-rentiel-item-titles-titres-ditems-partag-s-entre-coll-ges-official-plus-fr-q-b8a67ce6.md",".agent_memory/packets/decision-refonte-ux-ui-v2-direction-feuille-bloc-collega-ui-epic-8-r-f-rentiel-de-titres--752f4a56.md",".agent_memory/packets/decision-revue-qualit-fiches-prod-et-plan-chantier-4-d-ploiement-continu-671f678e.md",".agent_memory/packets/decision-session-du-jour-8-3-moteur-persistance-locale-synchro-des-fiches-un-r-import-ne--26c31dc9.md",".agent_memory/packets/decision-sessions-et-s-curit-apr-s-chantier-2-rotation-des-refresh-token-version-ip-clien-bb8935c1.md",".agent_memory/packets/decision-upload-par-morceaux-story-7-11-architecture-backend-init-parts-complete-helpers--6eee8fc0.md",".agent_memory/packets/gotcha-app-upload-par-morceaux-chunkeduploadservice-background-downloader-9-5-5-pi-ges--83a931c5.md",".agent_memory/packets/gotcha-ci-illisible-depuis-ce-mac-gh-crazygrower-la-rejouer-en-local-avec-act-et-le-con-bc7ad221.md",".agent_memory/packets/gotcha-collega-ui-8-2-r-gles-dassemblage-des-composants-pour-les-crans-f3c8b7d2.md",".agent_memory/packets/gotcha-collega-ui-police-embarqu-e-goldens-widgetbook-web-contrastes-jour-8-15-faf0c765.md",".agent_memory/packets/gotcha-formats-r-els-des-pdf-de-coll-ges-cep-cnec-pi-ges-de-litemdetector-et-o-relire-l-46d17c50.md",".agent_memory/packets/gotcha-prod-collegatest-2-chemins-r-seau-le-chemin-public-est-bloqu-par-cloudflare-acce-4c9884ac.md",".agent_memory/packets/gotcha-profil-me-rappel-quotidien-et-quota-pi-ges-8-14-2d47f0a8.md",".agent_memory/packets/gotcha-riverpod-ne-pas-invalider-un-provider-family-jamais-lu-en-debug-il-se-construit--3de106de.md",".agent_memory/packets/gotcha-routeur-gorouter-unique-refreshlistenable-ne-jamais-le-recr-er-sur-un-changement-4f6c8dc1.md",".agent_memory/packets/gotcha-sheets-routes-sans-page-et-gorouter-go-ne-les-ferme-pas-recherche-sheet-extrait--74575541.md",".agent_memory/packets/gotcha-tests-flutter-lancer-par-dossier-cibl-les-tests-home-ont-disparu-en-8-3-10b95ec1.md",".agent_memory/packets/gotcha-un-envoi-par-morceaux-en-cours-nexiste-pas-encore-c-t-serveur-245607fc.md",".agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md",".agent_memory/packets/repo_map-collega-repo-structure-0317f7c1.md",".agent_memory/packets/runbook-cloudflare-access-bypass-du-webhook-revenuecat-en-place-tester-le-chemin-public--59ea0e97.md",".agent_memory/packets/runbook-d-ployer-le-backend-collega-scripts-deploy-sh-image-par-commit-dump-image-tag-re-93cb38ee.md",".agent_memory/packets/runbook-d-ployer-le-backend-collega-sur-le-nas-build-amd64-push-docker-hub-compose-pull--34a7927b.md",".agent_memory/packets/runbook-deploy-sh-apr-s-revue-dump-clean-retour-arri-re-restaurer-le-dump-puis-red-ploye-fc9e7139.md",".agent_memory/packets/runbook-restauration-collega-prouv-e-dump-pg-dumpall-nocturne-2-erreurs-de-rejeu-normale-821d10ee.md",".agent_memory/packets/runbook-supervision-collega-health-alertes-panne-et-retour-en-niveau-alert-lagent-telegr-a8d5f36f.md",".agent_memory/packets/workflow-change-memory-feat-refonte-back-infra-da251790.md",".agent_memory/packets/workflow-story-7-11-d-ploy-e-et-v-rifi-e-en-prod-wi-fi-cancero-411-mb-en-17-morceaux-177--8ba9bed7.md",".agent_memory/pending/workflow-workflow-wrote-users-lesurmatthis-dev-projet-perso-collega-collega-backend-scrip-4ba29c91.md"],"summary_path":".agent_memory/review/branch-summary-feat-refonte-back-infra.json"}],"context":{"fact":"Current branch feat/refonte-back-infra changes 1 repo path.","why":"Branch change memory gives future agents durable context from the git diff when they continue, review, or verify this work.","trigger":"Recall when asking what changed on this branch, preparing a PR review, or resuming this work.","action":"Use the changed file list and diff summary as orientation, then inspect the actual diff and source files before making further edits.","verification":"Generated from git diff and refreshed by kage pr summarize or kage propose --from-diff.","risk_if_forgotten":"Future agents may repeat orientation work, miss branch-specific assumptions, or ignore files touched by this change.","stale_when":"The branch diff changes substantially, the branch is merged, or a newer change-memory packet supersedes it."},"freshness":{"last_verified_at":"2026-09-24T22:04:42.196Z","ttl_days":180,"path_fingerprints":[{"path":".DS_Store","sha256":"8364cde730c230c716dc390f80005bbf06422d7fed1eccb2d5436f97a052994d","size":6148}],"path_fingerprint_policy":"source_hash_staleness","verification":"git_diff"},"edges":[{"relation":"changes_path","to":"path:.DS_Store","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/bug_fix-crans-de-progression-empil-s-un-push-par-tat-importstreaming-rafales-status-n-st-c3e6a84b.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/bug_fix-import-timeout-coll-ge-vide-sse-coup-par-cloudflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/bug_fix-progression-coll-ge-les-fiches-locales-sont-d-sormais-toutes-synchronis-es-8-3-l-c6a82ada.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/convention-backend-apr-s-chantier-5-routes-par-domaine-apperror-pool-arq-du-lifespan-servic-ec008ce5.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/convention-rate-limit-slowapi-redis-login-5-min-par-ip-et-limites-par-route-ad092c92.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/convention-surface-api-r-duite-docs-redoc-et-openapi-json-en-prod-d-sactiv-s-post-v1-auth-r-0c4f0781.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-acc-s-backend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-drill-une-fiche-revoir-nest-r-ins-r-e-quune-fois-toast-2-s-la-2e-fois-elle-est-c-2cdcd000.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-g-n-ration-des-fiches-apr-s-chantier-4-d-coupage-r0-r10-prompt-p2-sonnet-5-claud-9dc1ef95.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-import-avancement-de-g-n-ration-n-fiches-pr-tes-8-13-publi-item-par-item-par-le--859a91a7.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-pipeline-dimport-chantier-1-apr-s-revue-empreintes-par-page-items-inchang-s-jama-4db54e68.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-r-f-rentiel-item-titles-titres-ditems-partag-s-entre-coll-ges-official-plus-fr-q-b8a67ce6.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-refonte-ux-ui-v2-direction-feuille-bloc-collega-ui-epic-8-r-f-rentiel-de-titres--752f4a56.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-revue-qualit-fiches-prod-et-plan-chantier-4-d-ploiement-continu-671f678e.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-session-du-jour-8-3-moteur-persistance-locale-synchro-des-fiches-un-r-import-ne--26c31dc9.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-sessions-et-s-curit-apr-s-chantier-2-rotation-des-refresh-token-version-ip-clien-bb8935c1.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-upload-par-morceaux-story-7-11-architecture-backend-init-parts-complete-helpers--6eee8fc0.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/gotcha-app-upload-par-morceaux-chunkeduploadservice-background-downloader-9-5-5-pi-ges--83a931c5.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/gotcha-ci-illisible-depuis-ce-mac-gh-crazygrower-la-rejouer-en-local-avec-act-et-le-con-bc7ad221.md","evidence":"git_diff"}],"quality":{"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":569,"admission":{"admit":true,"class":"candidate","score":70,"reasons":["durable memory type","has provenance","repo scoped or path grounded","has durable trigger, rationale, issue context, or explanation","substantive enough to reuse"],"risks":[]},"candidate_kind":"change_memory","review_boundary":"git_or_pr","promotion_requires_review":true,"uses_30d":20,"total_uses":27,"last_accessed_at":"2026-09-26T16:03:59.656Z"},"created_at":"2026-09-24T22:04:42.196Z","updated_at":"2026-09-24T22:04:42.196Z"}
```

