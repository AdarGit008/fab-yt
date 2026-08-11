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
- A browser with YouTube login: yt-dlp auto-detects Chrome/Firefox/Brave/Edge/Opera cookies on all platforms.
- Custom pattern `extract_principles` at `~/.config/fabric/patterns/extract_principles/system.md`

## Full Pipeline

```
YouTube URL
     │
     ▼
transcript.md           ← fabric --youtube / smry.ai / youtube-transcript-api / yt-dlp
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
   - fallback: smry.ai — prepend `https://smry.ai/` to YouTube URL, fetch with Pi `fetch_content` tool (readable mode)
   - fallback: fetch_content (Pi tool — Gemini-powered)
   - **If all methods fail**: script outputs `TRANSCRIPT_FAILED=1` — use `fetch_content` with `https://smry.ai/youtube.com/watch?v=VIDEO_ID`, write to `transcript.md`, re-run script with `--transcript transcript.md`
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

**Ranking formula:** `score = appearance_count × Σ(weight × consensus_strength)`

**Consensus strength** (per output match, 0.0–1.0):
- 1.0 = Near-identical phrasing across outputs (same core idea, same framing)
- 0.7 = Same core idea, different framing/wording
- 0.5 = Related concept, overlapping but distinct angle
- 0.3 = Tangential mention, loosely connected
- 0.0 = False match (same word, different meaning)

**Source weighting:**
| Output source | Weight | Rationale |
|--------------|--------|-----------|
| extract_principles | ×1.5 | Most curated, pattern-tuned output |
| extract_patterns | ×1.5 | Recurring concepts surfaced deliberately |
| extract_ideas | ×1.0 | Raw, unfiltered — lower signal density |
| extract_recommendations | ×1.0 | Actionable but may be context-specific |

**Scoring example:** A concept appearing in principles (1.0 match), patterns (0.7 match),
and ideas (0.5 match) scores: 3 × (1.5×1.0 + 1.5×0.7 + 1.0×0.5) = 3 × 3.05 = 9.15

Singletons (1 output only) discarded regardless of weight.

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
- Numeric scoring replaces ad-hoc judgment — use the ranking formula above.
- A concept appearing in 2+ outputs with near-identical phrasing scores higher than one appearing in 4 with different meanings (consensus strength penalizes weak matches).
- Discard anything appearing in only 1 output (singleton = noise).
- Aim for 15-25 consolidated concepts across all tiers.
- Sort tiers by descending score; use natural breaks in score distribution to set tier boundaries.

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
- **Structure:** claim = concept + falsifiable predicate.
  - ❌ "Always validate assumptions" — vague, not falsifiable.
  - ✅ "Teams that validate assumptions before project kickoff experience 30% fewer rework cycles" — testable, sourced.
  - ✅ "Validating assumptions reduces project risk" — falsifiable (could be disproven).
- Prioritize Tier 1 and Tier 2 concepts from consolidation.
- Tag each claim: `[Claim-N]`
- Aim for 10-20 claims. Quality over quantity.

### Phase 4 — Verification (Subagent Crews)

**Before fanning out:** Check whether subagents have `web_search` and/or
`fetch_content` tools available. If they don't, skip subagents entirely and
run verification in the parent session (call `web_search` / `fetch_content`
directly per claim).

**Source quality definitions:**

| Term | Definition | Examples |
|------|-----------|----------|
| **Authoritative (Tier 1)** | Primary research, official standards, widely-cited textbooks | Peer-reviewed papers, ISO standards, NIST, academic press |
| **Authoritative (Tier 2)** | Established industry sources, reputable journalism | Harvard Business Review, MIT Tech Review, Wired, The Verge |
| **Authoritative (Tier 3)** | Credible blogs, conference talks, practitioner accounts | Personal blogs of recognized experts, conference recordings, whitepapers |
| **Independent** | Sources from different organizations/authors/domains | Two .edu articles from same university ≠ independent. A .edu + .gov + .org = independent. |

**Parallel fan-out limits:** Cap at 5 concurrent subagents. If there are more than 5 claims,
batch them: verify 5 at a time, collect results, proceed to next batch.

For EACH claim, run a research subagent. Use parallel fan-out for efficiency.

**⚠️ Subagent tool requirement:** The subagent MUST have `web_search` and/or `fetch_content` tools available. Standard `worker` subagents only have bash/curl and cannot verify claims. Use a subagent type with web tools pre-configured, or verify claims in the parent session as a fallback.

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
- **VERIFIED** — all 3/3 independent, authoritative (Tier 1–3) sources corroborate the concept. No contradictions.
- **UNDECIDED** — only 1-2/3 sources corroborate, sources are ambiguous, or independence is questionable.
- **DISCARDED** — 0/3 sources support, all sources contradict, or only Tier-3-or-below sources found.

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
| 3 | **smry.ai** (prepend to URL) | Pi `fetch_content` tool | ✅ Yes |
| 4 | **fetch_content** (Pi tool) | Pi agent with Gemini | ✅ Yes |

## CLI Flags

```
-t, --transcript FILE  Use provided transcript (use '-' for stdin)
-o, --output-dir DIR   Override output directory (default: ~/pi_agent/projects/pi_research)
--dry-run              Validate setup without extracting or spending API credits
-h, --help             Show help message
```

## Failure Modes

| Problem | Action |
|---------|--------|
| `fab-yt.sh` not found | Clone the repo, ensure `chmod +x fab-yt.sh` |
| `fabric` not found | Install: `pip install fabric-ai` or check PATH |
| `extract_principles` pattern not found | Copy from repo: `cp patterns/extract_principles/system.md ~/.config/fabric/patterns/extract_principles/` |
| Transcript blocked (all bash methods) | Script tries: 0) fabric built-in, 1) youtube-transcript-api, 2) yt-dlp with browser cookies, 3) smry.ai via fetch_content, 4) fetch_content (Gemini). Use --transcript flag as workaround. |
| Fabric pattern fails | Writes a placeholder note in the output file |
| 0 concepts survive consolidation | Report honestly — the video may not contain actionable concepts |
| Fabric API key exhausted / rate-limited | Check `fabric --setup` or API key config. Wait and retry. |
| Very long transcript exceeds context window | Pre-chunk transcript with token-aware splitter before running fabric. |
| Non-English / garbled transcript | Pipeline may produce meaningless output. Check transcript language first. |
| Partial transcript (yt-dlp first portion) | Re-extract. Check line count proportional to video length. |
| Subagent lacks web_search/fetch_content tools | Use parent-session verification: orchestrator calls web tools directly per claim. |
| Disk space exhaustion | Ensure ~1GB free for output files and temp artifacts. |
| Network timeout during fabric calls | Bash script has no timeout. Run with `timeout 300 ./fab-yt.sh ...` if needed. |
