# Graph Report - fabric_youtube  (2026-08-09)

## Corpus Check
- 5 files · ~4,644 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 65 nodes · 69 edges · 8 communities
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `96e9e2e6`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- fab-yt.sh
- fab-yt
- Full Pipeline
- /fab-yt — YouTube → Fabric → Verified Concepts & Principles
- system.md
- fab-yt Pipeline Review
- Gap Analysis
- Correctness Findings

## God Nodes (most connected - your core abstractions)
1. `fab-yt` - 9 edges
2. `/fab-yt — YouTube → Fabric → Verified Concepts & Principles` - 9 edges
3. `Gap Analysis` - 7 edges
4. `fab-yt.sh script` - 6 edges
5. `info()` - 6 edges
6. `Full Pipeline` - 6 edges
7. `fab-yt Pipeline Review` - 6 edges
8. `Correctness Findings` - 6 edges
9. `ensure_playwright()` - 3 edges
10. `setup_cookies()` - 3 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (8 total, 0 thin omitted)

### Community 0 - "fab-yt.sh"
Cohesion: 0.30
Nodes (7): die(), ensure_playwright(), get_transcript_fetch_content(), info(), run_fabric(), setup_cookies(), fab-yt.sh script

### Community 1 - "fab-yt"
Cohesion: 0.17
Nodes (11): Credits, Extraction Methods (tried in order), fab-yt, Manual (CLI), Output Structure, Pipeline, Prerequisites, Setup (+3 more)

### Community 2 - "Full Pipeline"
Cohesion: 0.33
Nodes (6): Full Pipeline, Phase 1 & 2 — Bash (fab-yt.sh), Phase 2.5 — Consolidation (LLM), Phase 3 — Claims Synthesis (LLM), Phase 4 — Verification (Subagent Crews), Phase 5 — Report

### Community 3 - "/fab-yt — YouTube → Fabric → Verified Concepts & Principles"
Cohesion: 0.22
Nodes (8): Credits, Custom Pattern: extract_principles, Extraction Methods (tried in order), /fab-yt — YouTube → Fabric → Verified Concepts & Principles, Failure Modes, Output Structure, Prerequisites, Verification Tiers

### Community 4 - "system.md"
Cohesion: 0.33
Nodes (5): IDENTITY and PURPOSE, INPUT, OUTPUT INSTRUCTIONS, OUTPUT SECTIONS, STEPS

### Community 5 - "fab-yt Pipeline Review"
Cohesion: 0.29
Nodes (6): B1: Exit code 0 on transcript failure (`fab-yt.sh:374`), B2: Phases 2.5–5 are entirely manual (completeness gap), Critical Issues, fab-yt Pipeline Review, Summary, Verdict

### Community 6 - "Gap Analysis"
Cohesion: 0.29
Nodes (7): Design Concerns, Gap Analysis, Missing Edge Cases, Missing Extraction Angles, Missing Failure Documentation, Missing UX, Reliability

### Community 7 - "Correctness Findings"
Cohesion: 0.33
Nodes (6): Correctness Findings, Phase 1 — Transcript Extraction, Phase 2.5 — Consolidation, Phase 2 — Fabric Patterns, Phase 3 — Claims Synthesis, Phase 4 — Verification

## Knowledge Gaps
- **40 isolated node(s):** `Why this pipeline?`, `Prerequisites`, `Setup`, `Manual (CLI)`, `Output Structure` (+35 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `fab-yt Pipeline Review` connect `fab-yt Pipeline Review` to `Gap Analysis`, `Correctness Findings`?**
  _High betweenness centrality (0.065) - this node is a cross-community bridge._
- **Why does `Gap Analysis` connect `Gap Analysis` to `fab-yt Pipeline Review`?**
  _High betweenness centrality (0.046) - this node is a cross-community bridge._
- **Why does `Correctness Findings` connect `Correctness Findings` to `fab-yt Pipeline Review`?**
  _High betweenness centrality (0.040) - this node is a cross-community bridge._
- **What connects `Why this pipeline?`, `Prerequisites`, `Setup` to the rest of the system?**
  _40 weakly-connected nodes found - possible documentation gaps or missing edges._