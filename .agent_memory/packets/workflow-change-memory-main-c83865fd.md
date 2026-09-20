---
type: "Workflow"
title: "Change memory: main"
description: "Repo-local context for 10 changed repo paths on main."
resource: ".gitignore"
tags: ["change-memory", "diff-proposal", "repo-local", "branch:main"]
timestamp: "2026-09-20T20:14:47.123Z"
x-kage-id: "repo:git-github-com-tistech0-collega:workflow:change-memory-main"
x-kage-type: "workflow"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "verified"
x-kage-paths: [".gitignore", "_bmad-output/implementation-artifacts/7-10-hardening-securite-pre-prod.md", "_bmad-output/implementation-artifacts/sprint-status.yaml", "collega_app/lib/core/network/api_client.dart", "collega_app/lib/core/network/cloudflare_access.dart", "collega_app/lib/core/network/sse_client.dart", "collega_app/lib/env.dart", "collega_app/test/core/network/cloudflare_access_test.dart", "collega_backend/app/api/v1/colleges.py", "collega_backend/tests/api/test_colleges_stream.py"]
---

# Change memory: main

> Repo-local context for 10 changed repo paths on main.

Repo-local change memory generated from the current git diff.

Goal: preserve the durable context another agent should receive when it works in this repo later.

What changed:
- .gitignore
- _bmad-output/implementation-artifacts/7-10-hardening-securite-pre-prod.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
- collega_app/lib/core/network/api_client.dart
- collega_app/lib/core/network/cloudflare_access.dart
- collega_app/lib/core/network/sse_client.dart
- collega_app/lib/env.dart
- collega_app/test/core/network/cloudflare_access_test.dart
- collega_backend/app/api/v1/colleges.py
- collega_backend/tests/api/test_colleges_stream.py

Diff summary:
```text
.gitignore                                               | 11 ++++++++++-
 _bmad-output/implementation-artifacts/sprint-status.yaml |  3 ++-
 collega_app/lib/core/network/api_client.dart             |  9 ++++++++-
 collega_app/lib/core/network/sse_client.dart             |  6 ++++++
 collega_app/lib/env.dart                                 |  7 +++++++
 collega_backend/app/api/v1/colleges.py                   | 21 ++++++++++++++++++---
 6 files changed, 51 insertions(+), 6 deletions(-)
.agent_memory/packets/convention-docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-0f0a3cd4.md | untracked
.agent_memory/packets/convention-rate-limit-login-5-min-via-slowapi-redis-d99fb98f.md | untracked
.agent_memory/packets/decision-acc-s-backend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md | untracked
.agent_memory/packets/gotcha-prod-collegatest-2-chemins-r-seau-le-chemin-public-est-bloqu-par-cloudflare-acce-4c9884ac.md | untracked
.agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md | untracked
.agent_memory/packets/repo_map-collega-repo-structure-0317f7c1.md | untracked
.agent_memory/packets/workflow-change-memory-main-c83865fd.md | untracked
.gitattributes | untracked
AGENTS.md | untracked
CLAUDE.md | untracked
_bmad-output/implementation-artifacts/7-10-hardening-securite-pre-prod.md | untracked
collega_app/lib/core/network/cloudflare_access.dart | untracked
collega_app/test/core/network/cloudflare_access_test.dart | untracked
collega_back
… [+49 chars truncated]
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
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:workflow:change-memory-main","title":"Change memory: main","summary":"Repo-local context for 10 changed repo paths on main.","body":"Repo-local change memory generated from the current git diff.\n\nGoal: preserve the durable context another agent should receive when it works in this repo later.\n\nWhat changed:\n- .gitignore\n- _bmad-output/implementation-artifacts/7-10-hardening-securite-pre-prod.md\n- _bmad-output/implementation-artifacts/sprint-status.yaml\n- collega_app/lib/core/network/api_client.dart\n- collega_app/lib/core/network/cloudflare_access.dart\n- collega_app/lib/core/network/sse_client.dart\n- collega_app/lib/env.dart\n- collega_app/test/core/network/cloudflare_access_test.dart\n- collega_backend/app/api/v1/colleges.py\n- collega_backend/tests/api/test_colleges_stream.py\n\nDiff summary:\n```text\n.gitignore                                               | 11 ++++++++++-\n _bmad-output/implementation-artifacts/sprint-status.yaml |  3 ++-\n collega_app/lib/core/network/api_client.dart             |  9 ++++++++-\n collega_app/lib/core/network/sse_client.dart             |  6 ++++++\n collega_app/lib/env.dart                                 |  7 +++++++\n collega_backend/app/api/v1/colleges.py                   | 21 ++++++++++++++++++---\n 6 files changed, 51 insertions(+), 6 deletions(-)\n.agent_memory/packets/convention-docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-0f0a3cd4.md | untracked\n.agent_memory/packets/convention-rate-limit-login-5-min-via-slowapi-redis-d99fb98f.md | untracked\n.agent_memory/packets/decision-acc-s-backend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md | untracked\n.agent_memory/packets/gotcha-prod-collegatest-2-chemins-r-seau-le-chemin-public-est-bloqu-par-cloudflare-acce-4c9884ac.md | untracked\n.agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md | untracked\n.agent_memory/packets/repo_map-collega-repo-structure-0317f7c1.md | untracked\n.agent_memory/packets/workflow-change-memory-main-c83865fd.md | untracked\n.gitattributes | untracked\nAGENTS.md | untracked\nCLAUDE.md | untracked\n_bmad-output/implementation-artifacts/7-10-hardening-securite-pre-prod.md | untracked\ncollega_app/lib/core/network/cloudflare_access.dart | untracked\ncollega_app/test/core/network/cloudflare_access_test.dart | untracked\ncollega_back\n… [+49 chars truncated]\n```\n\nHow to verify:\n- Add the exact test, build, or manual verification command when you refine this memory.\n\nImprove this packet when more context is known:\n- The actual feature, fix, or refactor rationale.\n- Why the change was made, including relevant bugs, issues, decisions, and code explanations.\n- The package, API, command, or architectural pattern future agents should understand, verify, or reuse.\n- Any gotchas, follow-up risks, or branch-specific assumptions.\n\nPromote beyond this repo only after explicit org/global review.","type":"workflow","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.62,"tags":["change-memory","diff-proposal","repo-local","branch:main"],"paths":[".gitignore","_bmad-output/implementation-artifacts/7-10-hardening-securite-pre-prod.md","_bmad-output/implementation-artifacts/sprint-status.yaml","collega_app/lib/core/network/api_client.dart","collega_app/lib/core/network/cloudflare_access.dart","collega_app/lib/core/network/sse_client.dart","collega_app/lib/env.dart","collega_app/test/core/network/cloudflare_access_test.dart","collega_backend/app/api/v1/colleges.py","collega_backend/tests/api/test_colleges_stream.py"],"stack":[],"source_refs":[{"kind":"git_diff","branch":"main","head":"ce7522cf0a2bc6a1cc52c36fe7bd24bcaf07ae61","merge_base":"268c75396f19f989349ebfa0f31f198151442c7d","changed_files":[".agent_memory/packets/convention-docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-0f0a3cd4.md",".agent_memory/packets/convention-rate-limit-login-5-min-via-slowapi-redis-d99fb98f.md",".agent_memory/packets/decision-acc-s-backend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md",".agent_memory/packets/gotcha-prod-collegatest-2-chemins-r-seau-le-chemin-public-est-bloqu-par-cloudflare-acce-4c9884ac.md",".agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md",".agent_memory/packets/repo_map-collega-repo-structure-0317f7c1.md",".agent_memory/packets/workflow-change-memory-main-c83865fd.md",".gitattributes",".gitignore","AGENTS.md","CLAUDE.md","_bmad-output/implementation-artifacts/7-10-hardening-securite-pre-prod.md","_bmad-output/implementation-artifacts/sprint-status.yaml","collega_app/lib/core/network/api_client.dart","collega_app/lib/core/network/cloudflare_access.dart","collega_app/lib/core/network/sse_client.dart","collega_app/lib/env.dart","collega_app/test/core/network/cloudflare_access_test.dart","collega_backend/app/api/v1/colleges.py","collega_backend/tests/api/test_colleges_stream.py"],"summary_path":"/Users/lesurmatthis/dev/projet perso/collega/.agent_memory/review/branch-summary-main.json"}],"context":{"fact":"Current branch main changes 10 repo paths.","why":"Branch change memory gives future agents durable context from the git diff when they continue, review, or verify this work.","trigger":"Recall when asking what changed on this branch, preparing a PR review, or resuming this work.","action":"Use the changed file list and diff summary as orientation, then inspect the actual diff and source files before making further edits.","verification":"Generated from git diff and refreshed by kage pr summarize or kage propose --from-diff.","risk_if_forgotten":"Future agents may repeat orientation work, miss branch-specific assumptions, or ignore files touched by this change.","stale_when":"The branch diff changes substantially, the branch is merged, or a newer change-memory packet supersedes it."},"freshness":{"last_verified_at":"2026-09-20T20:14:47.123Z","ttl_days":180,"path_fingerprints":[{"path":".gitattributes","sha256":"dd1d80f381f0e64aaf95eb3e852b378db3f6ba23ba50320ef2a087152bc07c08","size":45},{"path":".gitignore","sha256":"2bd63b1dc7f7605b184be48ce84c5b58a2c441948acc073c8b58432d2168599d","size":329},{"path":"AGENTS.md","sha256":"215a04d6697beb39eec000eec19e4981137e07d51d10c5c20387085d2eb93224","size":4798},{"path":"CLAUDE.md","sha256":"215a04d6697beb39eec000eec19e4981137e07d51d10c5c20387085d2eb93224","size":4798},{"path":"_bmad-output/implementation-artifacts/7-10-hardening-securite-pre-prod.md","sha256":"d4a1622c0994d41a513923ecb6200e5def1bf16650bc69c6c491dce3183b7d93","size":16514},{"path":"_bmad-output/implementation-artifacts/sprint-status.yaml","sha256":"31140a90e677474589b0a8ca6e93b3ee5914e76cb07a0da605615cbb1b2103e3","size":14169},{"path":"collega_app/lib/core/network/api_client.dart","sha256":"3434a515a9674e44710d32886d7278f50e63147f5ebe6c3fbe6510451b72937d","size":4292},{"path":"collega_app/lib/core/network/cloudflare_access.dart","sha256":"a32c316b645efdeb49770cbf75de0602d5a6e2b3ee09b472e5bd9a8907083abc","size":660},{"path":"collega_app/lib/core/network/sse_client.dart","sha256":"09b8d5c5623e9cc836c5500429a2705f5b1337a4dbd81b8bd0c8d051777c1fd1","size":2358},{"path":"collega_app/lib/env.dart","sha256":"c26fc62c5ba664c370cffdbf1dfec87cd3148fb18b861c8ea76afff1378a1c09","size":813},{"path":"collega_app/test/core/network/cloudflare_access_test.dart","sha256":"9780cbb5c70c1ded23dc05aa3e045a77d743fd32a27ff66f6f85e164469fef09","size":831},{"path":"collega_backend/app/api/v1/colleges.py","sha256":"83ebf81c7ad68fcc2f0d4244276811aab99698ca3918de48b770903642afe35d","size":20868},{"path":"collega_backend/tests/api/test_colleges_stream.py","sha256":"756d9c7ac78e126b2a671f83487fa6d6ca69d9f39f379653ec11e45797ac04b6","size":2693}],"path_fingerprint_policy":"source_hash_staleness","verification":"git_diff"},"edges":[{"relation":"changes_path","to":"path:.agent_memory/packets/convention-docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-0f0a3cd4.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/convention-rate-limit-login-5-min-via-slowapi-redis-d99fb98f.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/decision-acc-s-backend-via-tunnel-cloudflare-service-token-dans-lapp-heartbeat-sse-limite-4e3de494.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/gotcha-prod-collegatest-2-chemins-r-seau-le-chemin-public-est-bloqu-par-cloudflare-acce-4c9884ac.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/repo_map-collega-repo-structure-0317f7c1.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/workflow-change-memory-main-c83865fd.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.gitattributes","evidence":"git_diff"},{"relation":"changes_path","to":"path:.gitignore","evidence":"git_diff"},{"relation":"changes_path","to":"path:AGENTS.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:CLAUDE.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:_bmad-output/implementation-artifacts/7-10-hardening-securite-pre-prod.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:_bmad-output/implementation-artifacts/sprint-status.yaml","evidence":"git_diff"},{"relation":"changes_path","to":"path:collega_app/lib/core/network/api_client.dart","evidence":"git_diff"},{"relation":"changes_path","to":"path:collega_app/lib/core/network/cloudflare_access.dart","evidence":"git_diff"},{"relation":"changes_path","to":"path:collega_app/lib/core/network/sse_client.dart","evidence":"git_diff"},{"relation":"changes_path","to":"path:collega_app/lib/env.dart","evidence":"git_diff"},{"relation":"changes_path","to":"path:collega_app/test/core/network/cloudflare_access_test.dart","evidence":"git_diff"},{"relation":"changes_path","to":"path:collega_backend/app/api/v1/colleges.py","evidence":"git_diff"},{"relation":"changes_path","to":"path:collega_backend/tests/api/test_colleges_stream.py","evidence":"git_diff"}],"quality":{"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":684,"admission":{"admit":true,"class":"candidate","score":70,"reasons":["durable memory type","has provenance","repo scoped or path grounded","has durable trigger, rationale, issue context, or explanation","substantive enough to reuse"],"risks":[]},"candidate_kind":"change_memory","review_boundary":"git_or_pr","promotion_requires_review":true,"uses_30d":5,"total_uses":10,"last_accessed_at":"2026-09-20T20:20:54.672Z"},"created_at":"2026-09-20T20:14:47.123Z","updated_at":"2026-09-20T20:14:47.123Z"}
```

