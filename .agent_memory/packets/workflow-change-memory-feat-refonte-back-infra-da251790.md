---
type: "Workflow"
title: "Change memory: feat/refonte-back-infra"
description: "Repo-local context for 1 changed repo path on feat/refonte-back-infra."
resource: ".DS_Store"
tags: ["change-memory", "diff-proposal", "repo-local", "branch:feat-refonte-back-infra"]
timestamp: "2026-09-24T17:20:41.594Z"
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
.agent_memory/audit/events.jsonl                                                 |  2 ++
 .agent_memory/packets/workflow-change-memory-feat-refonte-back-infra-da251790.md |  7 +++++--
 .agent_memory/review/memory-review.md                                            | 20 +++++++++++++++++---
 3 files changed, 24 insertions(+), 5 deletions(-)
.DS_Store | untracked
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
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:workflow:change-memory-feat-refonte-back-infra","title":"Change memory: feat/refonte-back-infra","summary":"Repo-local context for 1 changed repo path on feat/refonte-back-infra.","body":"Repo-local change memory generated from the current git diff.\n\nGoal: preserve the durable context another agent should receive when it works in this repo later.\n\nWhat changed:\n- .DS_Store\n\nDiff summary:\n```text\n.agent_memory/audit/events.jsonl                                                 |  2 ++\n .agent_memory/packets/workflow-change-memory-feat-refonte-back-infra-da251790.md |  7 +++++--\n .agent_memory/review/memory-review.md                                            | 20 +++++++++++++++++---\n 3 files changed, 24 insertions(+), 5 deletions(-)\n.DS_Store | untracked\n```\n\nHow to verify:\n- Add the exact test, build, or manual verification command when you refine this memory.\n\nImprove this packet when more context is known:\n- The actual feature, fix, or refactor rationale.\n- Why the change was made, including relevant bugs, issues, decisions, and code explanations.\n- The package, API, command, or architectural pattern future agents should understand, verify, or reuse.\n- Any gotchas, follow-up risks, or branch-specific assumptions.\n\nPromote beyond this repo only after explicit org/global review.","type":"workflow","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.62,"tags":["change-memory","diff-proposal","repo-local","branch:feat-refonte-back-infra"],"paths":[".DS_Store"],"stack":[],"source_refs":[{"kind":"git_diff","branch":"feat/refonte-back-infra","head":"b109ff3cca8c8e62b9756cf9a42fa4d08f17ced0","merge_base":"0e6a28dee59e846030b347d3480ccf2b6cbe47a8","changed_files":[".DS_Store",".agent_memory/packets/workflow-change-memory-feat-refonte-back-infra-da251790.md"],"summary_path":"/Users/lesurmatthis/dev/projet perso/collega/.agent_memory/review/branch-summary-feat-refonte-back-infra.json"}],"context":{"fact":"Current branch feat/refonte-back-infra changes 1 repo path.","why":"Branch change memory gives future agents durable context from the git diff when they continue, review, or verify this work.","trigger":"Recall when asking what changed on this branch, preparing a PR review, or resuming this work.","action":"Use the changed file list and diff summary as orientation, then inspect the actual diff and source files before making further edits.","verification":"Generated from git diff and refreshed by kage pr summarize or kage propose --from-diff.","risk_if_forgotten":"Future agents may repeat orientation work, miss branch-specific assumptions, or ignore files touched by this change.","stale_when":"The branch diff changes substantially, the branch is merged, or a newer change-memory packet supersedes it."},"freshness":{"last_verified_at":"2026-09-24T17:20:41.594Z","ttl_days":180,"path_fingerprints":[{"path":".DS_Store","sha256":"8364cde730c230c716dc390f80005bbf06422d7fed1eccb2d5436f97a052994d","size":6148}],"path_fingerprint_policy":"source_hash_staleness","verification":"git_diff"},"edges":[{"relation":"changes_path","to":"path:.DS_Store","evidence":"git_diff"},{"relation":"changes_path","to":"path:.agent_memory/packets/workflow-change-memory-feat-refonte-back-infra-da251790.md","evidence":"git_diff"}],"quality":{"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"stale_reasons":[],"estimated_tokens_saved":278,"admission":{"admit":true,"class":"candidate","score":70,"reasons":["durable memory type","has provenance","repo scoped or path grounded","has durable trigger, rationale, issue context, or explanation","substantive enough to reuse"],"risks":[]},"candidate_kind":"change_memory","review_boundary":"git_or_pr","promotion_requires_review":true},"created_at":"2026-09-24T17:20:41.594Z","updated_at":"2026-09-24T17:20:41.594Z"}
```

