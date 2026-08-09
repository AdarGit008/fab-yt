#!/usr/bin/env bash
set -euo pipefail

# ─── fab-yt-llm.sh ─── Scaffolded prompts for Phases 2.5–5
# Run after fab-yt.sh completes Phase 1-2.
# Outputs pre-filled prompt templates to stdout and to individual files.
#
# Usage:
#   ./fab-yt-llm.sh <OUTDIR>          # Read from fab-yt.sh output directory
#   ./fab-yt-llm.sh --help            # Show usage

# ─── helpers ───
die() { echo "❌ $1" >&2; exit 1; }
info() { echo "→ $1" >&2; }

# ─── parse args ───
OUTDIR=""
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            cat <<'HELP'
Usage: fab-yt-llm.sh <OUTDIR>

Generate scaffolded LLM prompts for Phases 2.5–5 of the fab-yt pipeline.

<OUTDIR> is the output directory from a completed fab-yt.sh run
(e.g., ~/pi_agent/projects/pi_research/fab-yt-09-07-2026-01/).

Output files written to <OUTDIR>:
  - prompt_consolidation.md   (Phase 2.5)
  - prompt_claims.md          (Phase 3)
  - prompt_verification.md    (Phase 4)
  - prompt_report.md          (Phase 5)

The LLM orchestrator should read each prompt file and execute the instructions.
HELP
            exit 0
            ;;
        -*)
            die "Unknown flag: $1"
            ;;
        *)
            OUTDIR="$1"
            shift
            ;;
    esac
done

[ -z "$OUTDIR" ] && die "Usage: fab-yt-llm.sh <OUTDIR>. Use --help for details."
[ -d "$OUTDIR" ] || die "Output directory not found: $OUTDIR"

# ─── source files ───
TRANSCRIPT="$OUTDIR/transcript.md"
PATTERNS="$OUTDIR/extract_patterns.md"
IDEAS="$OUTDIR/extract_ideas.md"
RECOMMENDATIONS="$OUTDIR/extract_recommendations.md"
PRINCIPLES="$OUTDIR/extract_principles.md"

for f in "$TRANSCRIPT" "$PATTERNS" "$IDEAS" "$RECOMMENDATIONS" "$PRINCIPLES"; do
    [ -f "$f" ] || die "Missing file: $f. Run fab-yt.sh first."
done

TR_LINES=$(wc -l < "$TRANSCRIPT")
P_LINES=$(wc -l < "$PATTERNS")
I_LINES=$(wc -l < "$IDEAS")
R_LINES=$(wc -l < "$RECOMMENDATIONS")
PR_LINES=$(wc -l < "$PRINCIPLES")

info "Transcript: $TR_LINES lines"
info "Patterns: $P_LINES | Ideas: $I_LINES | Recommendations: $R_LINES | Principles: $PR_LINES"

# ═══════════════════════════════════════════
# PHASE 2.5 — CONSOLIDATION
# ═══════════════════════════════════════════

CONSOLIDATION_PROMPT="$OUTDIR/prompt_consolidation.md"
info "Writing consolidation prompt..."
cat > "$CONSOLIDATION_PROMPT" <<'CONSOLIDATION_EOF'
# Phase 2.5 — Consolidation

Cross-reference all 4 fabric outputs below to find concepts, guidelines, and
principles that appear across multiple outputs. Rank by the scoring formula.

## Scoring Formula

```
score = appearance_count × Σ(weight × consensus_strength)
```

### Source Weights
| Output | Weight |
|--------|--------|
| extract_principles | ×1.5 |
| extract_patterns | ×1.5 |
| extract_ideas | ×1.0 |
| extract_recommendations | ×1.0 |

### Consensus Strength (per match)
| Score | Meaning |
|-------|---------|
| 1.0 | Near-identical phrasing (same core idea, same framing) |
| 0.7 | Same core idea, different framing/wording |
| 0.5 | Related concept, overlapping but distinct angle |
| 0.3 | Tangential mention, loosely connected |
| 0.0 | False match (same word, different meaning) |

## Rules
- Only include concepts, guidelines, principles, and mental models.
  No dates, events, biographical trivia, or unactionable facts.
- Discard singletons (concepts appearing in only 1 output).
- Aim for 15–25 consolidated concepts across all tiers.
- Sort by descending score; use natural score breaks for tier boundaries.

## Input Files
CONSOLIDATION_EOF

for f in "$PATTERNS" "$IDEAS" "$RECOMMENDATIONS" "$PRINCIPLES"; do
    echo "" >> "$CONSOLIDATION_PROMPT"
    echo "### $(basename "$f")" >> "$CONSOLIDATION_PROMPT"
    echo '```' >> "$CONSOLIDATION_PROMPT"
    cat "$f" >> "$CONSOLIDATION_PROMPT"
    echo '```' >> "$CONSOLIDATION_PROMPT"
done

cat >> "$CONSOLIDATION_PROMPT" <<'CONSOLIDATION_EOF'

## Output Format

Write `consolidation.md`:

```markdown
# Consolidated Concepts & Principles

## Methodology
Cross-referenced 4 fabric outputs. Scored by appearance_count × Σ(weight × consensus_strength).

### 🔴 Tier 1 — 4/4 outputs (Strongest consensus)
- **[Concept name]** (score: X.XX): [Single sentence description]
  - Appears in: patterns, ideas, recommendations, principles
  - Consensus: [breakdown per source]

### 🟠 Tier 2 — 3/4 outputs
- **[Concept name]** (score: X.XX): [Single sentence description]
  - Appears in: [which 3]
  - Consensus: [breakdown per source]

### 🟡 Tier 3 — 2/4 outputs
- **[Concept name]** (score: X.XX): [Single sentence description]
  - Appears in: [which 2]
  - Consensus: [breakdown per source]
```
CONSOLIDATION_EOF

info "✅ Consolidation prompt: $CONSOLIDATION_PROMPT"

# ═══════════════════════════════════════════
# PHASE 3 — CLAIMS SYNTHESIS
# ═══════════════════════════════════════════

CLAIMS_PROMPT="$OUTDIR/prompt_claims.md"
info "Writing claims prompt..."
cat > "$CLAIMS_PROMPT" <<'CLAIMS_EOF'
# Phase 3 — Claims Synthesis

From the consolidated concepts in `consolidation.md`, create atomic, verifiable
claims. Each claim = concept + falsifiable predicate.

## Structure
- ❌ Bad: "Always validate assumptions" — vague, not falsifiable.
- ✅ Good: "Teams that validate assumptions before project kickoff experience 30% fewer rework cycles"
- ✅ Good: "Validating assumptions reduces project risk" — falsifiable, testable.

## Rules
- One concept/guideline/principle per claim. Not facts, not events, not dates.
- Each claim must be something a person could apply or act on.
- Prioritize Tier 1 and Tier 2 concepts from consolidation.
- Tag each claim: `[Claim-N]`
- Aim for 10–20 claims. Quality over quantity.

## Input
Read `consolidation.md` in this directory.

## Output

Write `claims.md`:

```markdown
# Claims

## [Claim-1]
[A single, verifiable concept/guideline/principle. Must be actionable and falsifiable.]

## [Claim-2]
...
```
CLAIMS_EOF

info "✅ Claims prompt: $CLAIMS_PROMPT"

# ═══════════════════════════════════════════
# PHASE 4 — VERIFICATION
# ═══════════════════════════════════════════

VERIFICATION_PROMPT="$OUTDIR/prompt_verification.md"
info "Writing verification prompt..."
cat > "$VERIFICATION_PROMPT" <<'VERIFICATION_EOF'
# Phase 4 — Verification

Verify each claim against 3 independent, authoritative web sources.

## Source Quality
| Tier | Definition | Examples |
|------|-----------|----------|
| Tier 1 | Primary research, official standards, widely-cited textbooks | Peer-reviewed papers, ISO, NIST |
| Tier 2 | Established industry sources, reputable journalism | HBR, MIT Tech Review, Wired |
| Tier 3 | Credible blogs, conference talks, practitioner accounts | Expert blogs, whitepapers |

**Independent** = different organizations/authors/domains.
Two .edu articles from same university ≠ independent.
.edu + .gov + .org = independent.

## Execution
- Cap at 5 concurrent subagents. Batch claims if >5.
- Subagents need `web_search` and/or `fetch_content` tools.
- If subagents lack web tools, verify in parent session directly.

## Subagent Task Template
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

## Classification
- **VERIFIED** — 3/3 independent, authoritative (Tier 1–3) sources corroborate.
- **UNDECIDED** — 1–2/3 corroborate, ambiguous, or questionable independence.
- **DISCARDED** — 0/3 support, all contradict, or only Tier-3-or-below sources.

## Input
Read `claims.md` in this directory.
VERIFICATION_EOF

info "✅ Verification prompt: $VERIFICATION_PROMPT"

# ═══════════════════════════════════════════
# PHASE 5 — REPORT
# ═══════════════════════════════════════════

REPORT_PROMPT="$OUTDIR/prompt_report.md"
info "Writing report prompt..."
cat > "$REPORT_PROMPT" <<'REPORT_EOF'
# Phase 5 — Report

Compile all verification results into a final report.

## Input
Read `verification.md` in this directory (produced by Phase 4).

## Output

Write the final report to `report.md`:

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
REPORT_EOF

info "✅ Report prompt: $REPORT_PROMPT"

# ─── summary ───
echo ""
echo "╔══════════════════════════════════════╗"
echo "║  fab-yt-llm Phase 2.5-5 prompts      ║"
echo "╠══════════════════════════════════════╣"
echo "║  1. $CONSOLIDATION_PROMPT"
echo "║  2. $CLAIMS_PROMPT"
echo "║  3. $VERIFICATION_PROMPT"
echo "║  4. $REPORT_PROMPT"
echo "╠══════════════════════════════════════╣"
echo "║  Feed each prompt to the LLM in      ║"
echo "║  order. Results chain forward.        ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "OUTDIR=$OUTDIR"
