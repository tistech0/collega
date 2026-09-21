---
type: "Repo Map"
title: "collega repo structure"
description: "Detected repo structure: README.md, CLAUDE.md, AGENTS.md. This packet is generated and should be treated as a navigation aid, not deep semantic understanding."
resource: "README.md"
tags: ["repo", "structure", "index"]
timestamp: "2026-09-21"
x-kage-id: "repo:git-github-com-tistech0-collega:repo_map:collega-repo-structure-auto-structure"
x-kage-type: "repo_map"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "verified"
x-kage-paths: ["README.md", "CLAUDE.md", "AGENTS.md"]
---

# collega repo structure

> Detected repo structure: README.md, CLAUDE.md, AGENTS.md. This packet is generated and should be treated as a navigat…

Detected repo structure: README.md, CLAUDE.md, AGENTS.md.
This packet is generated and should be treated as a navigation aid, not deep semantic understanding.

## Why

Agents need a quick map of repo entry points before choosing which files, workflows, or tests to inspect.

## Trigger

Recall when orienting to this repo's layout, CI workflows, or test locations.

## Action

Use this as a starting map and verify details against the current filesystem or code graph before editing.

## Verification

Generated from files present in the repository.

## Risk if forgotten

Agents may miss important entry points such as AGENTS.md, workflows, or MCP tests during initial orientation.

## Stale when

Top-level repo structure, workflow files, or test files change.

# Citations

[1] file README.md
[2] file CLAUDE.md
[3] file AGENTS.md

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:repo_map:collega-repo-structure-auto-structure","title":"collega repo structure","summary":"Detected repo structure: README.md, CLAUDE.md, AGENTS.md. This packet is generated and should be treated as a navigation aid, not deep semantic understanding.","body":"Detected repo structure: README.md, CLAUDE.md, AGENTS.md.\nThis packet is generated and should be treated as a navigation aid, not deep semantic understanding.","type":"repo_map","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.65,"tags":["repo","structure","index"],"paths":["README.md","CLAUDE.md","AGENTS.md"],"stack":[],"source_refs":[{"kind":"file","path":"README.md"},{"kind":"file","path":"CLAUDE.md"},{"kind":"file","path":"AGENTS.md"}],"context":{"fact":"Generated repo structure summarizes top-level files, workflows, and test files as a navigation aid.","why":"Agents need a quick map of repo entry points before choosing which files, workflows, or tests to inspect.","trigger":"Recall when orienting to this repo's layout, CI workflows, or test locations.","action":"Use this as a starting map and verify details against the current filesystem or code graph before editing.","verification":"Generated from files present in the repository.","risk_if_forgotten":"Agents may miss important entry points such as AGENTS.md, workflows, or MCP tests during initial orientation.","stale_when":"Top-level repo structure, workflow files, or test files change."},"freshness":{"ttl_days":30,"last_verified_at":"2026-09-21","verification":"source_seen"},"edges":[],"quality":{"reviewer":"kage-indexer","votes_up":0,"votes_down":0,"uses_30d":6,"reports_stale":0,"total_uses":12,"last_accessed_at":"2026-09-21T14:00:04.984Z"},"created_at":"2026-07-04T13:28:22.550Z","updated_at":"2026-09-21T13:17:53.682Z"}
```

