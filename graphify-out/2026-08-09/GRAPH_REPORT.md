# Graph Report - fabric_youtube  (2026-08-09)

## Corpus Check
- 4 files · ~3,198 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 44 nodes · 48 edges · 7 communities (5 shown, 2 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `53fbcd1e`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- fab-yt.sh
- fab-yt
- Full Pipeline
- /fab-yt — YouTube → Fabric → Verified Concepts & Principles
- system.md
- Usage
- Pipeline

## God Nodes (most connected - your core abstractions)
1. `fab-yt` - 9 edges
2. `/fab-yt — YouTube → Fabric → Verified Concepts & Principles` - 9 edges
3. `fab-yt.sh script` - 6 edges
4. `Full Pipeline` - 6 edges
5. `info()` - 5 edges
6. `ensure_playwright()` - 3 edges
7. `setup_cookies()` - 3 edges
8. `run_fabric()` - 3 edges
9. `die()` - 2 edges
10. `Pipeline` - 2 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (7 total, 2 thin omitted)

### Community 0 - "fab-yt.sh"
Cohesion: 0.33
Nodes (6): die(), ensure_playwright(), info(), run_fabric(), setup_cookies(), fab-yt.sh script

### Community 1 - "fab-yt"
Cohesion: 0.25
Nodes (7): Credits, Extraction Methods (tried in order), fab-yt, Output Structure, Prerequisites, Setup, Verification Tiers

### Community 2 - "Full Pipeline"
Cohesion: 0.33
Nodes (6): Full Pipeline, Phase 1 & 2 — Bash (fab-yt.sh), Phase 2.5 — Consolidation (LLM), Phase 3 — Claims Synthesis (LLM), Phase 4 — Verification (Subagent Crews), Phase 5 — Report

### Community 3 - "/fab-yt — YouTube → Fabric → Verified Concepts & Principles"
Cohesion: 0.22
Nodes (8): Credits, Custom Pattern: extract_principles, Extraction Methods (tried in order), /fab-yt — YouTube → Fabric → Verified Concepts & Principles, Failure Modes, Output Structure, Prerequisites, Verification Tiers

### Community 4 - "system.md"
Cohesion: 0.33
Nodes (5): IDENTITY and PURPOSE, INPUT, OUTPUT INSTRUCTIONS, OUTPUT SECTIONS, STEPS

## Knowledge Gaps
- **25 isolated node(s):** `Why this pipeline?`, `Prerequisites`, `Setup`, `Manual (CLI)`, `Output Structure` (+20 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `/fab-yt — YouTube → Fabric → Verified Concepts & Principles` connect `/fab-yt — YouTube → Fabric → Verified Concepts & Principles` to `Full Pipeline`?**
  _High betweenness centrality (0.084) - this node is a cross-community bridge._
- **Why does `Full Pipeline` connect `Full Pipeline` to `/fab-yt — YouTube → Fabric → Verified Concepts & Principles`?**
  _High betweenness centrality (0.061) - this node is a cross-community bridge._
- **Why does `fab-yt` connect `fab-yt` to `Usage`, `Pipeline`?**
  _High betweenness centrality (0.059) - this node is a cross-community bridge._
- **What connects `Why this pipeline?`, `Prerequisites`, `Setup` to the rest of the system?**
  _25 weakly-connected nodes found - possible documentation gaps or missing edges._