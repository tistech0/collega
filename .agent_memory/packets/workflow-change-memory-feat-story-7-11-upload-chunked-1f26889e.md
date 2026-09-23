---
type: "Workflow"
title: "Change memory: feat/story-7.11-upload-chunked"
description: "Repo-local context for 18 changed repo paths on feat/story-7.11-upload-chunked."
resource: ".gitattributes"
tags: ["change-memory", "diff-proposal", "repo-local", "branch:feat-story-7-11-upload-chunked"]
timestamp: "2026-09-23T09:15:51.573Z"
x-kage-id: "repo:git-github-com-tistech0-collega:workflow:change-memory-feat-story-7-11-upload-chunked"
x-kage-type: "workflow"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "verified"
x-kage-paths: [".gitattributes", "AGENTS.md", "CLAUDE.md"]
---

# Change memory: feat/story-7.11-upload-chunked

> Repo-local context for 18 changed repo paths on feat/story-7.11-upload-chunked.

Repo-local change memory generated from the current git diff.

Goal: preserve the durable context another agent should receive when it works in this repo later.

What changed:
- .agent_memory/packets/bug_fix-college-status-n-tait-jamais-avanc-generation-complete-job-seulement-import-jama-5ea68aac.md
- .agent_memory/packets/bug_fix-crans-de-progression-empil-s-un-push-par-tat-importstreaming-rafales-status-n-st-c3e6a84b.md
- .agent_memory/packets/bug_fix-import-timeout-coll-ge-vide-sse-coup-par-cloudflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md
- .agent_memory/packets/bug_fix-progression-coll-ge-0-0-fiches-vs-barre-pleine-fiches-locales-items-ouverts-seul-291959c6.md
- .agent_memory/packets/decision-acc-s-backend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md
- .agent_memory/packets/decision-drill-une-fiche-revoir-nest-r-ins-r-e-quune-fois-toast-2-s-la-2e-fois-elle-est-c-2cdcd000.md
- .agent_memory/packets/decision-upload-par-morceaux-story-7-11-architecture-backend-init-parts-complete-helpers--6eee8fc0.md
- .agent_memory/packets/gotcha-app-upload-par-morceaux-chunkeduploadservice-background-downloader-9-5-5-pi-ges--83a931c5.md
- .agent_memory/packets/gotcha-flutter-test-complet-home-notifier-test-choue-binding-non-initialis-et-la-suite--fe089895.md
- .agent_memory/packets/gotcha-prod-collegatest-2-chemins-r-seau-le-chemin-public-est-bloqu-par-cloudflare-acce-4c9884ac.md
- .agent_memory/packets/gotcha-shadcn-ui-shadprogress-le-rail-prend-colorscheme-secondary-vert-chez-nous-barre--06414cf9.md
- .agent_memory/packets/workflow-change-memory-feat-story-7-11-upload-chunked-1f26889e.md
- .agent_memory/packets/workflow-change-memory-main-c83865fd.md
- .agent_memory/packets/workflow-story-7-11-d-ploy-e-et-v-rifi-e-en-prod-wi-fi-cancero-411-mb-en-17-morceaux-177--8ba9bed7.md
- .agent_memory/pending/bug_fix-pasted-content-id-36da-contexte-projet-collega-flutter-app-collega-app-backend-f-e23c92d0.md
- .gitattributes
- AGENTS.md
- CLAUDE.md

Diff summary:
```text
.agent_memory/audit/events.jsonl                                                         | 12 +++++++++
 .agent_memory/branches/main.json                                                         | 32 +++---------------------
 ...-status-n-tait-jamais-avanc-generation-complete-job-seulement-import-jama-5ea68aac.md |  7 +++---
 ...e-progression-empil-s-un-push-par-tat-importstreaming-rafales-status-n-st-c3e6a84b.md |  7 +++---
 ...timeout-coll-ge-vide-sse-coup-par-cloudflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md |  5 ++--
 ...ackend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md |  7 +++---
 ...llegatest-2-chemins-r-seau-le-chemin-public-est-bloqu-par-cloudflare-acce-4c9884ac.md |  2 +-
 .agent_memory/packets/workflow-change-memory-main-c83865fd.md                            | 40 +++++++++++++++---------------
 .agent_memory/review/branch-summary-main.json                                            | 16 ++++--------
 .agent_memory/review/memory-review.md                                                    | 59 ++++++++++++++++++++++++++++++--------------
 10 files changed, 97 insertions(+), 90 deletions(-)
.agent_memory/packets/bug_fix-progression-coll-ge-0-0-fiches-vs-barre-pleine-fiches-locales-items-ouverts-seul-291959c6.md | untracked
.agent_memory/packets/decision-drill-une-fiche-revoir-nest-r-ins-r-e-quune-fois-toast-2-s-la-2e-fois-elle-est-c-2cdcd000.md | untracked
.agent_memory/packets/decision-upload-par-morceaux-story-7-11-architecture
… [+905 chars truncated]
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
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:workflow:change-memory-feat-story-7-11-upload-chunked","title":"Change memory: feat/story-7.11-upload-chunked","summary":"Repo-local context for 18 changed repo paths on feat/story-7.11-upload-chunked.","body":"Repo-local change memory generated from the current git diff.\n\nGoal: preserve the durable context another agent should receive when it works in this repo later.\n\nWhat changed:\n- .agent_memory/packets/bug_fix-college-status-n-tait-jamais-avanc-generation-complete-job-seulement-import-jama-5ea68aac.md\n- .agent_memory/packets/bug_fix-crans-de-progression-empil-s-un-push-par-tat-importstreaming-rafales-status-n-st-c3e6a84b.md\n- .agent_memory/packets/bug_fix-import-timeout-coll-ge-vide-sse-coup-par-cloudflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md\n- .agent_memory/packets/bug_fix-progression-coll-ge-0-0-fiches-vs-barre-pleine-fiches-locales-items-ouverts-seul-291959c6.md\n- .agent_memory/packets/decision-acc-s-backend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md\n- .agent_memory/packets/decision-drill-une-fiche-revoir-nest-r-ins-r-e-quune-fois-toast-2-s-la-2e-fois-elle-est-c-2cdcd000.md\n- .agent_memory/packets/decision-upload-par-morceaux-story-7-11-architecture-backend-init-parts-complete-helpers--6eee8fc0.md\n- .agent_memory/packets/gotcha-app-upload-par-morceaux-chunkeduploadservice-background-downloader-9-5-5-pi-ges--83a931c5.md\n- .agent_memory/packets/gotcha-flutter-test-complet-home-notifier-test-choue-binding-non-initialis-et-la-suite--fe089895.md\n- .agent_memory/packets/gotcha-prod-collegatest-2-chemins-r-seau-le-chemin-public-est-bloqu-par-cloudflare-acce-4c9884ac.md\n- .agent_memory/packets/gotcha-shadcn-ui-shadprogress-le-rail-prend-colorscheme-secondary-vert-chez-nous-barre--06414cf9.md\n- .agent_memory/packets/workflow-change-memory-feat-story-7-11-upload-chunked-1f26889e.md\n- .agent_memory/packets/workflow-change-memory-main-c83865fd.md\n- .agent_memory/packets/workflow-story-7-11-d-ploy-e-et-v-rifi-e-en-prod-wi-fi-cancero-411-mb-en-17-morceaux-177--8ba9bed7.md\n- .agent_memory/pending/bug_fix-pasted-content-id-36da-contexte-projet-collega-flutter-app-collega-app-backend-f-e23c92d0.md\n- .gitattributes\n- AGENTS.md\n- CLAUDE.md\n\nDiff summary:\n```text\n.agent_memory/audit/events.jsonl                                                         | 12 +++++++++\n .agent_memory/branches/main.json                                                         | 32 +++---------------------\n ...-status-n-tait-jamais-avanc-generation-complete-job-seulement-import-jama-5ea68aac.md |  7 +++---\n ...e-progression-empil-s-un-push-par-tat-importstreaming-rafales-status-n-st-c3e6a84b.md |  7 +++---\n ...timeout-coll-ge-vide-sse-coup-par-cloudflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md |  5 ++--\n ...ackend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md |  7 +++---\n ...llegatest-2-chemins-r-seau-le-chemin-public-est-bloqu-par-cloudflare-acce-4c9884ac.md |  2 +-\n .agent_memory/packets/workflow-change-memory-main-c83865fd.md                            | 40 +++++++++++++++---------------\n .agent_memory/review/branch-summary-main.json                                            | 16 ++++--------\n .agent_memory/review/memory-review.md                                                    | 59 ++++++++++++++++++++++++++++++--------------\n 10 files changed, 97 insertions(+), 90 deletions(-)\n.agent_memory/packets/bug_fix-progression-coll-ge-0-0-fiches-vs-barre-pleine-fiches-locales-items-ouverts-seul-291959c6.md | untracked\n.agent_memory/packets/decision-drill-une-fiche-revoir-nest-r-ins-r-e-quune-fois-toast-2-s-la-2e-fois-elle-est-c-2cdcd000.md | untracked\n.agent_memory/packets/decision-upload-par-morceaux-story-7-11-architecture\n… [+905 chars truncated]\n```\n\nHow to verify:\n- Add the exact test, build, or manual verification command when you refine this memory.\n\nImprove this packet when more context is known:\n- The actual feature, fix, or refactor rationale.\n- Why the change was made, including relevant bugs, issues, decisions, and code explanations.\n- The package, API, command, or architectural pattern future agents should understand, verify, or reuse.\n- Any gotchas, follow-up risks, or branch-specific assumptions.\n\nPromote beyond this repo only after explicit org/global review.","type":"workflow","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.62,"tags":["change-memory","diff-proposal","repo-local","branch:feat-story-7-11-upload-chunked"],"paths":[".gitattributes","AGENTS.md","CLAUDE.md"],"stack":[],"source_refs":[{"kind":"git_diff","branch":"feat/story-7.11-upload-chunked","head":"395b5890adb79c6c755d0f6da3cb91cfebda4cfa","merge_base":"c56e83c5f9cffb6fc3a466f8879dfed8524abbc5","changed_files":[".agent_memory/packets/bug_fix-college-status-n-tait-jamais-avanc-generation-complete-job-seulement-import-jama-5ea68aac.md",".agent_memory/packets/bug_fix-crans-de-progression-empil-s-un-push-par-tat-importstreaming-rafales-status-n-st-c3e6a84b.md",".agent_memory/packets/bug_fix-import-timeout-coll-ge-vide-sse-coup-par-cloudflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md",".agent_memory/packets/bug_fix-progression-coll-ge-0-0-fiches-vs-barre-pleine-fiches-locales-items-ouverts-seul-291959c6.md",".agent_memory/packets/decision-acc-s-backend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md",".agent_memory/packets/decision-drill-une-fiche-revoir-nest-r-ins-r-e-quune-fois-toast-2-s-la-2e-fois-elle-est-c-2cdcd000.md",".agent_memory/packets/decision-upload-par-morceaux-story-7-11-architecture-backend-init-parts-complete-helpers--6eee8fc0.md",".agent_memory/packets/gotcha-app-upload-par-morceaux-chunkeduploadservice-background-downloader-9-5-5-pi-ges--83a931c5.md",".agent_memory/packets/gotcha-flutter-test-complet-home-notifier-test-choue-binding-non-initialis-et-la-suite--fe089895.md",".agent_memory/packets/gotcha-prod-collegatest-2-chemins-r-seau-le-chemin-public-est-bloqu-par-cloudflare-acce-4c9884ac.md",".agent_memory/packets/gotcha-shadcn-ui-shadprogress-le-rail-prend-colorscheme-secondary-vert-chez-nous-barre--06414cf9.md",".agent_memory/packets/workflow-change-memory-feat-story-7-11-upload-chunked-1f26889e.md",".agent_memory/packets/workflow-change-memory-main-c83865fd.md",".agent_memory/packets/workflow-story-7-11-d-ploy-e-et-v-rifi-e-en-prod-wi-fi-cancero-411-mb-en-17-morceaux-177--8ba9bed7.md",".agent_memory/pending/bug_fix-pasted-content-id-36da-contexte-projet-collega-flutter-app-collega-app-backend-f-e23c92d0.md",".gitattributes","AGENTS.md","CLAUDE.md"],"summary_path":"/Users/lesurmatthis/dev/projet perso/collega/.agent_memory/review/branch-summary-feat-story-7-11-upload-chunked.json"}],"context":{"fact":"Current branch feat/story-7.11-upload-chunked changes 18 repo paths.","why":"Branch change memory gives future agents durable context from the git diff when they continue, review, or verify this work.","trigger":"Recall when asking what changed on this branch, preparing a PR review, or resuming this work.","action":"Use the changed file list and diff summary as orientation, then inspect the actual diff and source files before making further edits.","verification":"Generated from git diff and refreshed by kage pr summarize or kage propose --from-diff.","risk_if_forgotten":"Future agents may repeat orientation work, miss branch-specific assumptions, or ignore files touched by this change.","stale_when":"The branch diff changes substantially, the branch is merged, or a newer change-memory packet supersedes it."},"freshness":{"last_verified_at":"2026-09-23T09:15:51.573Z","ttl_days":180,"path_fingerprints":[{"path":".gitattributes","sha256":"dd1d80f381f0e64aaf95eb3e852b378db3f6ba23ba50320ef2a087152bc07c08","size":45},{"path":"AGENTS.md","sha256":"215a04d6697beb39eec000eec19e4981137e07d51d10c5c20387085d2eb93224","size":4798},{"path":"CLAUDE.md","sha256":"215a04d6697beb39eec000eec19e4981137e07d51d10c5c20387085d2eb93224","size":4798}],"path_fingerprint_policy":"source_hash_staleness","verification":"evidence_reverification"},"edges":[{"relation":"changes_path","to":"path:.agent_memory/packets/bug_fix-college-status-n-tait-jamais-avanc-generation-complete-job-seulement-import-jama-5ea68aac.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/bug_fix-crans-de-progression-empil-s-un-push-par-tat-importstreaming-rafales-status-n-st-c3e6a84b.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/bug_fix-import-timeout-coll-ge-vide-sse-coup-par-cloudflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/bug_fix-progression-coll-ge-0-0-fiches-vs-barre-pleine-fiches-locales-items-ouverts-seul-291959c6.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-acc-s-backend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-drill-une-fiche-revoir-nest-r-ins-r-e-quune-fois-toast-2-s-la-2e-fois-elle-est-c-2cdcd000.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-upload-par-morceaux-story-7-11-architecture-backend-init-parts-complete-helpers--6eee8fc0.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/gotcha-app-upload-par-morceaux-chunkeduploadservice-background-downloader-9-5-5-pi-ges--83a931c5.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/gotcha-flutter-test-complet-home-notifier-test-choue-binding-non-initialis-et-la-suite--fe089895.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/gotcha-prod-collegatest-2-chemins-r-seau-le-chemin-public-est-bloqu-par-cloudflare-acce-4c9884ac.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/gotcha-shadcn-ui-shadprogress-le-rail-prend-colorscheme-secondary-vert-chez-nous-barre--06414cf9.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/workflow-change-memory-feat-story-7-11-upload-chunked-1f26889e.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/workflow-change-memory-main-c83865fd.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/workflow-story-7-11-d-ploy-e-et-v-rifi-e-en-prod-wi-fi-cancero-411-mb-en-17-morceaux-177--8ba9bed7.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/pending/bug_fix-pasted-content-id-36da-contexte-projet-collega-flutter-app-collega-app-backend-f-e23c92d0.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.gitattributes","evidence":"git_diff"},{"relation":"changes_path","to":"path:AGENTS.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:CLAUDE.md","evidence":"git_diff"}],"quality":{"score":82,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":["some referenced paths are missing: .agent_memory/packets/workflow-change-memory-feat-story-7-11-upload-chunked-1f26889e.md"],"duplicate_candidates":[],"estimated_tokens_saved":1020,"admission":{"admit":true,"class":"candidate","score":70,"reasons":["durable memory type","has provenance","repo scoped or path grounded","has durable trigger, rationale, issue context, or explanation","substantive enough to reuse"],"risks":[]},"candidate_kind":"change_memory","review_boundary":"git_or_pr","promotion_requires_review":true,"uses_30d":4,"total_uses":4,"last_accessed_at":"2026-09-21T18:57:01.509Z","reverified_at":"2026-09-23T09:15:51.573Z"},"created_at":"2026-09-21T18:50:01.049Z","updated_at":"2026-09-23T09:15:51.573Z"}
```

