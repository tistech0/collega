---
type: "Workflow"
title: "Change memory: main"
description: "Repo-local context for 1 changed repo path on main."
resource: "collega_app/ios/Runner.xcodeproj/project.pbxproj"
tags: ["change-memory", "diff-proposal", "repo-local", "branch:main"]
timestamp: "2026-09-21T14:02:43.653Z"
x-kage-id: "repo:git-github-com-tistech0-collega:workflow:change-memory-main"
x-kage-type: "workflow"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "verified"
x-kage-paths: ["collega_app/ios/Runner.xcodeproj/project.pbxproj"]
---

# Change memory: main

> Repo-local context for 1 changed repo path on main.

Repo-local change memory generated from the current git diff.

Goal: preserve the durable context another agent should receive when it works in this repo later.

What changed:
- collega_app/ios/Runner.xcodeproj/project.pbxproj

Diff summary:
```text
.agent_memory/audit/events.jsonl                         |  2 +
 ...ration-complete-job-seulement-import-jama-5ea68aac.md |  2 +-
 ...r-cloudflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md |  7 +--
 ...tiv-et-post-v1-auth-register-bloqu-en-403-0f0a3cd4.md |  2 +-
 ...-rate-limit-login-5-min-via-slowapi-redis-d99fb98f.md |  2 +-
 ...vice-token-dans-lapp-heartbeat-sse-limite-4e3de494.md |  2 +-
 ...emin-public-est-bloqu-par-cloudflare-acce-4c9884ac.md |  2 +-
 .../packets/repo_map-collega-repo-overview-cf8b6e00.md   |  4 +-
 .../packets/repo_map-collega-repo-structure-0317f7c1.md  |  4 +-
 .../packets/workflow-change-memory-main-c83865fd.md      | 57 ++++++++++---------------
 .agent_memory/review/branch-summary-main.json            | 24 ++++-------
 .agent_memory/review/memory-review.md                    | 41 +++++++++---------
 collega_app/ios/Runner.xcodeproj/project.pbxproj         |  7 ++-
 13 files changed, 71 insertions(+), 85 deletions(-)
.agent_memory/packets/bug_fix-crans-de-progression-empil-s-un-push-par-tat-importstreaming-rafales-status-n-st-c3e6a84b.md | untracked
.agent_memory/packets/runbook-d-ployer-le-backend-en-prod-nas-unraid-build-amd64-push-docker-hub-compose-pull--0117012e.md | untracked
.gitattributes | untracked
AGENTS.md | untracked
CLAUDE.md | untracked
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
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:workflow:change-memory-main","title":"Change memory: main","summary":"Repo-local context for 1 changed repo path on main.","body":"Repo-local change memory generated from the current git diff.\n\nGoal: preserve the durable context another agent should receive when it works in this repo later.\n\nWhat changed:\n- collega_app/ios/Runner.xcodeproj/project.pbxproj\n\nDiff summary:\n```text\n.agent_memory/audit/events.jsonl                         |  2 +\n ...ration-complete-job-seulement-import-jama-5ea68aac.md |  2 +-\n ...r-cloudflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md |  7 +--\n ...tiv-et-post-v1-auth-register-bloqu-en-403-0f0a3cd4.md |  2 +-\n ...-rate-limit-login-5-min-via-slowapi-redis-d99fb98f.md |  2 +-\n ...vice-token-dans-lapp-heartbeat-sse-limite-4e3de494.md |  2 +-\n ...emin-public-est-bloqu-par-cloudflare-acce-4c9884ac.md |  2 +-\n .../packets/repo_map-collega-repo-overview-cf8b6e00.md   |  4 +-\n .../packets/repo_map-collega-repo-structure-0317f7c1.md  |  4 +-\n .../packets/workflow-change-memory-main-c83865fd.md      | 57 ++++++++++---------------\n .agent_memory/review/branch-summary-main.json            | 24 ++++-------\n .agent_memory/review/memory-review.md                    | 41 +++++++++---------\n collega_app/ios/Runner.xcodeproj/project.pbxproj         |  7 ++-\n 13 files changed, 71 insertions(+), 85 deletions(-)\n.agent_memory/packets/bug_fix-crans-de-progression-empil-s-un-push-par-tat-importstreaming-rafales-status-n-st-c3e6a84b.md | untracked\n.agent_memory/packets/runbook-d-ployer-le-backend-en-prod-nas-unraid-build-amd64-push-docker-hub-compose-pull--0117012e.md | untracked\n.gitattributes | untracked\nAGENTS.md | untracked\nCLAUDE.md | untracked\n```\n\nHow to verify:\n- Add the exact test, build, or manual verification command when you refine this memory.\n\nImprove this packet when more context is known:\n- The actual feature, fix, or refactor rationale.\n- Why the change was made, including relevant bugs, issues, decisions, and code explanations.\n- The package, API, command, or architectural pattern future agents should understand, verify, or reuse.\n- Any gotchas, follow-up risks, or branch-specific assumptions.\n\nPromote beyond this repo only after explicit org/global review.","type":"workflow","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.62,"tags":["change-memory","diff-proposal","repo-local","branch:main"],"paths":["collega_app/ios/Runner.xcodeproj/project.pbxproj"],"stack":[],"source_refs":[{"kind":"git_diff","branch":"main","head":"1a55430a417b3a9012332d264de7e08785c95dcb","merge_base":"b33e433be7b365671897a91eb9fb18d9d83f1bc0","changed_files":[".agent_memory/packets/bug_fix-college-status-n-tait-jamais-avanc-generation-complete-job-seulement-import-jama-5ea68aac.md",".agent_memory/packets/bug_fix-crans-de-progression-empil-s-un-push-par-tat-importstreaming-rafales-status-n-st-c3e6a84b.md",".agent_memory/packets/bug_fix-import-timeout-coll-ge-vide-sse-coup-par-cloudflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md",".agent_memory/packets/convention-docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-0f0a3cd4.md",".agent_memory/packets/convention-rate-limit-login-5-min-via-slowapi-redis-d99fb98f.md",".agent_memory/packets/decision-acc-s-backend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md",".agent_memory/packets/gotcha-prod-collegatest-2-chemins-r-seau-le-chemin-public-est-bloqu-par-cloudflare-acce-4c9884ac.md",".agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md",".agent_memory/packets/repo_map-collega-repo-structure-0317f7c1.md",".agent_memory/packets/runbook-d-ployer-le-backend-en-prod-nas-unraid-build-amd64-push-docker-hub-compose-pull--0117012e.md",".agent_memory/packets/workflow-change-memory-main-c83865fd.md",".gitattributes","AGENTS.md","CLAUDE.md","collega_app/ios/Runner.xcodeproj/project.pbxproj"],"summary_path":"/Users/lesurmatthis/dev/projet perso/collega/.agent_memory/review/branch-summary-main.json"}],"context":{"fact":"Current branch main changes 1 repo path.","why":"Branch change memory gives future agents durable context from the git diff when they continue, review, or verify this work.","trigger":"Recall when asking what changed on this branch, preparing a PR review, or resuming this work.","action":"Use the changed file list and diff summary as orientation, then inspect the actual diff and source files before making further edits.","verification":"Generated from git diff and refreshed by kage pr summarize or kage propose --from-diff.","risk_if_forgotten":"Future agents may repeat orientation work, miss branch-specific assumptions, or ignore files touched by this change.","stale_when":"The branch diff changes substantially, the branch is merged, or a newer change-memory packet supersedes it."},"freshness":{"last_verified_at":"2026-09-21T14:02:43.653Z","ttl_days":180,"path_fingerprints":[{"path":".gitattributes","sha256":"dd1d80f381f0e64aaf95eb3e852b378db3f6ba23ba50320ef2a087152bc07c08","size":45},{"path":"AGENTS.md","sha256":"215a04d6697beb39eec000eec19e4981137e07d51d10c5c20387085d2eb93224","size":4798},{"path":"CLAUDE.md","sha256":"215a04d6697beb39eec000eec19e4981137e07d51d10c5c20387085d2eb93224","size":4798},{"path":"collega_app/ios/Runner.xcodeproj/project.pbxproj","sha256":"185a2fb5d501413a2fe395231e7e16245e1386ba87b59258ac185141a6004eab","size":31177}],"path_fingerprint_policy":"source_hash_staleness","verification":"git_diff"},"edges":[{"relation":"changes_path","to":"path:.agent_memory/packets/bug_fix-college-status-n-tait-jamais-avanc-generation-complete-job-seulement-import-jama-5ea68aac.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/bug_fix-crans-de-progression-empil-s-un-push-par-tat-importstreaming-rafales-status-n-st-c3e6a84b.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/bug_fix-import-timeout-coll-ge-vide-sse-coup-par-cloudflare-apr-s-90-s-de-silence-app-sa-ef1271f2.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/convention-docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-0f0a3cd4.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/convention-rate-limit-login-5-min-via-slowapi-redis-d99fb98f.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-acc-s-backend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/gotcha-prod-collegatest-2-chemins-r-seau-le-chemin-public-est-bloqu-par-cloudflare-acce-4c9884ac.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/repo_map-collega-repo-structure-0317f7c1.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/runbook-d-ployer-le-backend-en-prod-nas-unraid-build-amd64-push-docker-hub-compose-pull--0117012e.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/workflow-change-memory-main-c83865fd.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.gitattributes","evidence":"git_diff"},{"relation":"changes_path","to":"path:AGENTS.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:CLAUDE.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:collega_app/ios/Runner.xcodeproj/project.pbxproj","evidence":"git_diff"}],"quality":{"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"stale_reasons":[],"estimated_tokens_saved":522,"admission":{"admit":true,"class":"candidate","score":70,"reasons":["durable memory type","has provenance","repo scoped or path grounded","has durable trigger, rationale, issue context, or explanation","substantive enough to reuse"],"risks":[]},"candidate_kind":"change_memory","review_boundary":"git_or_pr","promotion_requires_review":true},"created_at":"2026-09-21T14:02:43.653Z","updated_at":"2026-09-21T14:02:43.653Z"}
```

