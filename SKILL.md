---
name: fab-yt
description: "Extract concepts, guidelines, and principles from YouTube videos, verify them, and report findings. Trigger: /fab-yt <youtube-link>"
---

# /fab-yt — YouTube → Fabric → Verified Concepts & Principles

Extract a YouTube transcript, run it through fabric patterns tuned for concepts/guidelines/principles,
cross-reference outputs to surface the most-iterated ideas, verify the top ones with web research, and report.

## Prerequisites

- `fabric` CLI v1.4.459+: `~/.local/bin/fabric` (or on PATH). Includes built-in YouTube transcript extraction.
- `yt-dlp`, `youtube-transcript-api`: auto-installed if missing
- Playwright + Chromium: auto-installed if needed (tertiary fallback; skip with `SKIP_PLAYWRIGHT=1`)
- A browser with YouTube login: yt-dlp auto-detects Chrome/Firefox/Brave/Edge/Opera cookies on all platforms.
- Custom pattern `extract_principles` at `~/.config/fabric/patterns/extract_principles/system.md`

## Full Pipeline

```
YouTube URL
     │
     ▼
transcript.md           ← fabric --youtube / youtube-transcript-api / yt-dlp / Playwright
     │
     ├── extract_patterns       → recurring concepts
     ├── extract_ideas          → all ideas
     ├── extract_recommendations → actionable items
     └── extract_principles     → principles & guidelines (custom)
     │
     ▼
consolidation.md         ← LLM cross-references 4 outputs, ranks by iteration count
     │
     ▼
claims.md                ← Top N most-iterated concepts become claims
     │
     ▼
verification.md          ← Subagent crews verify each claim (3 sources)
     │
     ▼
Chat report              ← VERIFIED / UNDECIDED / DISCARDED
```

### Phase 1 & 2 — Bash (fab-yt.sh)

```
1. Extract transcript → transcript.md
   - fabric --youtube (built-in, v1.4.459+)
   - fallback: youtube-transcript-api
   - fallback: yt-dlp with browser cookies
   - fallback: Playwright headless Chromium
2. Run 4 fabric patterns:
   - extract_patterns — finds recurring concepts across the transcript
   - extract_ideas — captures all ideas mentioned
   - extract_recommendations — extracts actionable recommendations
   - extract_principles — custom pattern for principles, guidelines, mental models
3. Output: transcript.md, extract_patterns.md, extract_ideas.md, extract_recommendations.md, extract_principles.md
```

### Phase 2.5 — Consolidation (LLM)

**This is the critical new step.** Read all 4 fabric output files. Cross-reference them to find concepts, guidelines, and principles that appear across multiple outputs. The more outputs a concept appears in, the more important it is.

Write `consolidation.md`:

```markdown
# Consolidated Concepts & Principles

## Methodology
Cross-referenced 4 fabric outputs: patterns, ideas, recommendations, principles.
Ranked by: (appearance count × consensus strength). Singletons discarded.

## Top Concepts by Iteration Count

### 🔴 Tier 1 — 4/4 outputs (Strongest consensus)
- **[Concept name]**: [Single sentence description]
  - Appears in: patterns, ideas, recommendations, principles
  - Source lines: "...", "..."

### 🟠 Tier 2 — 3/4 outputs
- **[Concept name]**: [Single sentence description]
  - Appears in: [which 3]
  - Source lines: "..."

### 🟡 Tier 3 — 2/4 outputs
- **[Concept name]**: [Single sentence description]
  - Appears in: [which 2]
  - Source lines: "..."
```

Rules:
- **Only include concepts, guidelines, principles, and mental models.** No dates, events, biographical trivia, or unactionable facts.
- Weight extract_principles and extract_patterns higher — they're the most curated outputs.
- A concept appearing in 2+ outputs with near-identical phrasing is stronger than one appearing in 4 with different meanings.
- Discard anything that appears in only 1 output (singleton = noise).
- Aim for 15-25 consolidated concepts across all tiers.

### Phase 3 — Claims Synthesis (LLM)

From the consolidated concepts, create atomic, verifiable claims. Write `claims.md`:

```markdown
# Claims

## [Claim-1]
A single, verifiable concept/guideline/principle. Must be actionable.

## [Claim-2]
...
```

Rules:
- **One concept/guideline/principle per claim.** Not facts, not events, not dates.
- Each claim must be something a person could apply or act on.
- Prioritize Tier 1 and Tier 2 concepts from consolidation.
- Tag each claim: `[Claim-N]`
- Aim for 10-20 claims. Quality over quantity.

### Phase 4 — Verification (Subagent Crews)

For EACH claim, run a research subagent. Use parallel fan-out for efficiency.

**Subagent task template:**
```
Verify this concept/principle against web sources. Find exactly 3 independent,
authoritative sources. For each source, provide:
- The exact quote that supports or contradicts the concept
- The URL

Claim: [claim text]

Output format:
## [Claim-N]
**Status:** VERIFIED | UNDECIDED | DISCARDED

### Source 1
**Quote:** "..."
**URL:** https://...

### Source 2
**Quote:** "..."
**URL:** https://...

### Source 3
**Quote:** "..."
**URL:** https://...

**Verdict:** [brief reasoning]
```

**Classification:**
- **VERIFIED** — all 3/3 sources corroborate the concept. No contradictions.
- **UNDECIDED** — only 1-2/3 sources corroborate, or sources are ambiguous.
- **DISCARDED** — 0/3 sources support the concept, or all sources contradict.

Be tough but fair. A concept is only VERIFIED when 3 independent, authoritative sources agree.

### Phase 5 — Report

Write `verification.md` with all results, grouped by status:

```markdown
# Verification Report
**Video:** [URL]
**Date:** [date]
**Concepts analyzed:** N
**VERIFIED:** V | **UNDECIDED:** U | **DISCARDED:** D

## ✅ VERIFIED
[verified concepts with sources]

## 🤔 UNDECIDED
[undecided concepts with sources]

## ❌ DISCARDED
[discarded concepts with brief reason]
```

**Print to chat:**
```
## fab-yt Results

### ✅ VERIFIED (all)
- [Concept/principle] — [brief source note]

### 🤔 UNDECIDED
- [Concept/principle] — [brief note on why]

### ❌ DISCARDED
- [Concept/principle] — [reason]
```

## Output Structure

```
~/pi_agent/projects/pi_research/fab-yt-DD-MM-YYYY-NN/
├── transcript.md
├── extract_patterns.md
├── extract_ideas.md
├── extract_recommendations.md
├── extract_principles.md
├── consolidation.md
├── claims.md
└── verification.md
```

## Verification Tiers

| Tier | Sources | Meaning |
|------|---------|---------|
| ✅ VERIFIED | 3/3 corroborate | Concept survives |
| 🤔 UNDECIDED | 1-2/3 corroborate | Insufficient evidence |
| ❌ DISCARDED | 0/3 corroborate | Concept rejected |

## Credits

- **fabric** patterns by [Daniel Miessler](https://github.com/danielmiessler/fabric)
- **yt-dlp** by the yt-dlp contributors
- **youtube-transcript-api** by jdepoix
- **Playwright** by Microsoft

## Custom Pattern: extract_principles

The `extract_principles` pattern is maintained in this repo at `patterns/extract_principles/system.md`.
Install it:

```bash
mkdir -p ~/.config/fabric/patterns/extract_principles
cp patterns/extract_principles/system.md ~/.config/fabric/patterns/extract_principles/system.md
```

## Extraction Methods (tried in order)

| # | Method | Requirements | Works on VPS? |
|---|--------|-------------|---------------|
| 0 | `fabric --youtube` | fabric v1.4.459+ | ✅ Yes |
| 1 | `youtube-transcript-api` | Python package | ❌ Often blocked |
| 2 | `yt-dlp` + browser cookies | Logged-in browser | ❌ Needs display |
| 3 | **Playwright headless** | Auto-installs Chromium (~500MB) | ✅ Yes |

## Failure Modes

| Problem | Action |
|---------|--------|
| \`fab-yt.sh\` not found | Clone the repo, ensure \`chmod +x fab-yt.sh\` |
| \`fabric\` not found | Install: \`pip install fabric-ai\` or check PATH |
| \`extract_principles\` pattern not found | Copy from repo: \`cp patterns/extract_principles/system.md ~/.config/fabric/patterns/extract_principles/\` |
| Transcript blocked (all bash methods) | Orchestrator: use \`fetch_content\` tool → save output → re-run with \`--transcript\` |
| Fabric pattern fails | Writes a placeholder note in the output file |
| 0 concepts survive consolidation | Report honestly — the video may not contain actionable concepts |
| Fabric API key exhausted / rate-limited | Check \`fabric --setup\` or API key config. Wait and retry. |
| Very long transcript exceeds context window | Pre-chunk transcript with token-aware splitter before running fabric. |
| Non-English / garbled transcript | Pipeline may produce meaningless output. Check transcript language first. |
| Partial transcript (yt-dlp first portion) | Re-extract. Check line count proportional to video length. |
| Subagent lacks web_search/fetch_content tools | Use parent-session verification: orchestrator calls web tools directly per claim. |
| Disk space exhaustion | Ensure ~1GB free for output files, Playwright Chromium, and temp artifacts. |
| Network timeout during fabric calls | Bash script has no timeout. Run with \`timeout 300 ./fab-yt.sh ...\` if needed. |
