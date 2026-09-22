---
type: "Workflow"
title: "Change memory: feat/redesign-ux-ui"
description: "Repo-local context for 1 changed repo path on feat/redesign-ux-ui."
resource: ".agent_memory/pending/bug_fix-pasted-content-id-656b-contexte-projet-collega-flutter-app-collega-app-backend-f-29717d15.md"
tags: ["change-memory", "diff-proposal", "repo-local", "branch:feat-redesign-ux-ui"]
timestamp: "2026-09-22T19:32:37.806Z"
x-kage-id: "repo:git-github-com-tistech0-collega:workflow:change-memory-feat-redesign-ux-ui"
x-kage-type: "workflow"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "verified"
x-kage-paths: [".agent_memory/pending/bug_fix-pasted-content-id-656b-contexte-projet-collega-flutter-app-collega-app-backend-f-29717d15.md"]
---

# Change memory: feat/redesign-ux-ui

> Repo-local context for 1 changed repo path on feat/redesign-ux-ui.

Repo-local change memory generated from the current git diff.

Goal: preserve the durable context another agent should receive when it works in this repo later.

What changed:
- .agent_memory/pending/bug_fix-pasted-content-id-656b-contexte-projet-collega-flutter-app-collega-app-backend-f-29717d15.md

Diff summary:
```text
.agent_memory/audit/events.jsonl              | 13 +++++++++++++
 .agent_memory/review/branch-summary-main.json | 21 ++++++++++++++-------
 .agent_memory/review/memory-review.md         | 89 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-----------------------
 3 files changed, 93 insertions(+), 30 deletions(-)
.agent_memory/pending/bug_fix-pasted-content-id-656b-contexte-projet-collega-flutter-app-collega-app-backend-f-29717d15.md | untracked
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
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:workflow:change-memory-feat-redesign-ux-ui","title":"Change memory: feat/redesign-ux-ui","summary":"Repo-local context for 1 changed repo path on feat/redesign-ux-ui.","body":"Repo-local change memory generated from the current git diff.\n\nGoal: preserve the durable context another agent should receive when it works in this repo later.\n\nWhat changed:\n- .agent_memory/pending/bug_fix-pasted-content-id-656b-contexte-projet-collega-flutter-app-collega-app-backend-f-29717d15.md\n\nDiff summary:\n```text\n.agent_memory/audit/events.jsonl              | 13 +++++++++++++\n .agent_memory/review/branch-summary-main.json | 21 ++++++++++++++-------\n .agent_memory/review/memory-review.md         | 89 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-----------------------\n 3 files changed, 93 insertions(+), 30 deletions(-)\n.agent_memory/pending/bug_fix-pasted-content-id-656b-contexte-projet-collega-flutter-app-collega-app-backend-f-29717d15.md | untracked\n```\n\nHow to verify:\n- Add the exact test, build, or manual verification command when you refine this memory.\n\nImprove this packet when more context is known:\n- The actual feature, fix, or refactor rationale.\n- Why the change was made, including relevant bugs, issues, decisions, and code explanations.\n- The package, API, command, or architectural pattern future agents should understand, verify, or reuse.\n- Any gotchas, follow-up risks, or branch-specific assumptions.\n\nPromote beyond this repo only after explicit org/global review.","type":"workflow","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.62,"tags":["change-memory","diff-proposal","repo-local","branch:feat-redesign-ux-ui"],"paths":[".agent_memory/pending/bug_fix-pasted-content-id-656b-contexte-projet-collega-flutter-app-collega-app-backend-f-29717d15.md"],"stack":[],"source_refs":[{"kind":"git_diff","branch":"feat/redesign-ux-ui","head":"c0a5c1f8968d6ea654ca2d4a38318aa98eb09adc","merge_base":"6d0a0eeb566a8722ef1808e976422a0672fba8d3","changed_files":[".agent_memory/pending/bug_fix-pasted-content-id-656b-contexte-projet-collega-flutter-app-collega-app-backend-f-29717d15.md"],"summary_path":"/Users/lesurmatthis/dev/projet perso/collega/.agent_memory/review/branch-summary-feat-redesign-ux-ui.json"}],"context":{"fact":"Current branch feat/redesign-ux-ui changes 1 repo path.","why":"Branch change memory gives future agents durable context from the git diff when they continue, review, or verify this work.","trigger":"Recall when asking what changed on this branch, preparing a PR review, or resuming this work.","action":"Use the changed file list and diff summary as orientation, then inspect the actual diff and source files before making further edits.","verification":"Generated from git diff and refreshed by kage pr summarize or kage propose --from-diff.","risk_if_forgotten":"Future agents may repeat orientation work, miss branch-specific assumptions, or ignore files touched by this change.","stale_when":"The branch diff changes substantially, the branch is merged, or a newer change-memory packet supersedes it."},"freshness":{"last_verified_at":"2026-09-22T19:32:37.806Z","ttl_days":180,"path_fingerprints":[],"path_fingerprint_policy":"source_hash_staleness","verification":"git_diff"},"edges":[{"relation":"changes_path","to":"path:.agent_memory/pending/bug_fix-pasted-content-id-656b-contexte-projet-collega-flutter-app-collega-app-backend-f-29717d15.md","evidence":"git_diff"}],"quality":{"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"stale_reasons":[],"estimated_tokens_saved":332,"admission":{"admit":true,"class":"candidate","score":70,"reasons":["durable memory type","has provenance","repo scoped or path grounded","has durable trigger, rationale, issue context, or explanation","substantive enough to reuse"],"risks":[]},"candidate_kind":"change_memory","review_boundary":"git_or_pr","promotion_requires_review":true},"created_at":"2026-09-22T19:32:37.806Z","updated_at":"2026-09-22T19:32:37.806Z"}
```

