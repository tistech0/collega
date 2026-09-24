---
type: "Workflow"
title: "Change memory: feat/chantier-1-fiabilite-imports"
description: "Repo-local context for 3 changed repo paths on feat/chantier-1-fiabilite-imports."
resource: ".agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md"
tags: ["change-memory", "diff-proposal", "repo-local", "branch:feat-chantier-1-fiabilite-imports"]
timestamp: "2026-09-24T05:30:15.330Z"
x-kage-id: "repo:git-github-com-tistech0-collega:workflow:change-memory-feat-chantier-1-fiabilite-imports"
x-kage-type: "workflow"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "verified"
x-kage-paths: [".agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md", ".agent_memory/packets/repo_map-collega-repo-structure-0317f7c1.md", ".agent_memory/packets/workflow-change-memory-feat-chantier-1-fiabilite-imports-4431e2ff.md"]
---

# Change memory: feat/chantier-1-fiabilite-imports

> Repo-local context for 3 changed repo paths on feat/chantier-1-fiabilite-imports.

Repo-local change memory generated from the current git diff.

Goal: preserve the durable context another agent should receive when it works in this repo later.

What changed:
- .agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md
- .agent_memory/packets/repo_map-collega-repo-structure-0317f7c1.md
- .agent_memory/packets/workflow-change-memory-feat-chantier-1-fiabilite-imports-4431e2ff.md

Diff summary:
```text
.agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md                         |  4 +--
 .agent_memory/packets/repo_map-collega-repo-structure-0317f7c1.md                        |  4 +--
 .../packets/workflow-change-memory-feat-chantier-1-fiabilite-imports-4431e2ff.md         | 64 +++++++++++---------------------------------
 .agent_memory/review/branch-summary-feat-chantier-1-fiabilite-imports.json               | 52 +++++------------------------------
 .agent_memory/review/memory-review.md                                                    | 59 +++++++---------------------------------
 5 files changed, 34 insertions(+), 149 deletions(-)
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
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:workflow:change-memory-feat-chantier-1-fiabilite-imports","title":"Change memory: feat/chantier-1-fiabilite-imports","summary":"Repo-local context for 3 changed repo paths on feat/chantier-1-fiabilite-imports.","body":"Repo-local change memory generated from the current git diff.\n\nGoal: preserve the durable context another agent should receive when it works in this repo later.\n\nWhat changed:\n- .agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md\n- .agent_memory/packets/repo_map-collega-repo-structure-0317f7c1.md\n- .agent_memory/packets/workflow-change-memory-feat-chantier-1-fiabilite-imports-4431e2ff.md\n\nDiff summary:\n```text\n.agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md                         |  4 +--\n .agent_memory/packets/repo_map-collega-repo-structure-0317f7c1.md                        |  4 +--\n .../packets/workflow-change-memory-feat-chantier-1-fiabilite-imports-4431e2ff.md         | 64 +++++++++++---------------------------------\n .agent_memory/review/branch-summary-feat-chantier-1-fiabilite-imports.json               | 52 +++++------------------------------\n .agent_memory/review/memory-review.md                                                    | 59 +++++++---------------------------------\n 5 files changed, 34 insertions(+), 149 deletions(-)\n```\n\nHow to verify:\n- Add the exact test, build, or manual verification command when you refine this memory.\n\nImprove this packet when more context is known:\n- The actual feature, fix, or refactor rationale.\n- Why the change was made, including relevant bugs, issues, decisions, and code explanations.\n- The package, API, command, or architectural pattern future agents should understand, verify, or reuse.\n- Any gotchas, follow-up risks, or branch-specific assumptions.\n\nPromote beyond this repo only after explicit org/global review.","type":"workflow","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.62,"tags":["change-memory","diff-proposal","repo-local","branch:feat-chantier-1-fiabilite-imports"],"paths":[".agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md",".agent_memory/packets/repo_map-collega-repo-structure-0317f7c1.md",".agent_memory/packets/workflow-change-memory-feat-chantier-1-fiabilite-imports-4431e2ff.md"],"stack":[],"source_refs":[{"kind":"git_diff","branch":"feat/chantier-1-fiabilite-imports","head":"92d3e216ab5913ba0abe29225b6fc15948bfc855","merge_base":"0a522d91fba5a33095074066a670d93aeac2d683","changed_files":[".agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md",".agent_memory/packets/repo_map-collega-repo-structure-0317f7c1.md",".agent_memory/packets/workflow-change-memory-feat-chantier-1-fiabilite-imports-4431e2ff.md"],"summary_path":"/Users/lesurmatthis/dev/projet perso/collega/.agent_memory/review/branch-summary-feat-chantier-1-fiabilite-imports.json"}],"context":{"fact":"Current branch feat/chantier-1-fiabilite-imports changes 3 repo paths.","why":"Branch change memory gives future agents durable context from the git diff when they continue, review, or verify this work.","trigger":"Recall when asking what changed on this branch, preparing a PR review, or resuming this work.","action":"Use the changed file list and diff summary as orientation, then inspect the actual diff and source files before making further edits.","verification":"Generated from git diff and refreshed by kage pr summarize or kage propose --from-diff.","risk_if_forgotten":"Future agents may repeat orientation work, miss branch-specific assumptions, or ignore files touched by this change.","stale_when":"The branch diff changes substantially, the branch is merged, or a newer change-memory packet supersedes it."},"freshness":{"last_verified_at":"2026-09-24T05:30:15.330Z","ttl_days":180,"path_fingerprints":[],"path_fingerprint_policy":"source_hash_staleness","verification":"git_diff"},"edges":[{"relation":"changes_path","to":"path:.agent_memory/packets/repo_map-collega-repo-overview-cf8b6e00.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/repo_map-collega-repo-structure-0317f7c1.md","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/workflow-change-memory-feat-chantier-1-fiabilite-imports-4431e2ff.md","evidence":"git_diff"}],"quality":{"score":82,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":["some referenced paths are missing: .agent_memory/packets/workflow-change-memory-feat-chantier-1-fiabilite-imports-4431e2ff.md"],"duplicate_candidates":[],"stale_reasons":["some referenced paths are missing: .agent_memory/packets/workflow-change-memory-feat-chantier-1-fiabilite-imports-4431e2ff.md"],"estimated_tokens_saved":405,"admission":{"admit":true,"class":"candidate","score":70,"reasons":["durable memory type","has provenance","repo scoped or path grounded","has durable trigger, rationale, issue context, or explanation","substantive enough to reuse"],"risks":[]},"candidate_kind":"change_memory","review_boundary":"git_or_pr","promotion_requires_review":true},"created_at":"2026-09-24T05:30:15.330Z","updated_at":"2026-09-24T05:30:15.330Z"}
```

