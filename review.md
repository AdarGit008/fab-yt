# fab-yt Pipeline Review

**Date:** 2026-08-09
**Reviewers:** Correctness subagent (94a505e6), Gaps subagent (29c3b2b6)
**Scope:** Full pipeline — `fab-yt.sh`, `SKILL.md`, `patterns/extract_principles/system.md`, `README.md`

---

## Verdict

The pipeline **architecture is sound** — multi-angle extraction → cross-referencing → claims → verification is excellent methodology. The transcript extraction cascade is well-layered. Documentation is thorough.

**Two critical issues** must be addressed: (1) Phases 2.5–5 are entirely manual with zero automation, and (2) the script exits 0 on transcript failure.

---

## Critical Issues

### B1: Exit code 0 on transcript failure (`fab-yt.sh:374`)

When all transcript methods fail, the script writes `.transcript_failed`, prints `TRANSCRIPT_FAILED=1`, then does `exit 0`. Orchestrators relying on exit codes will think the run succeeded. Should be `exit 1` (or a distinct non-zero code).

### B2: Phases 2.5–5 are entirely manual (completeness gap)

The bash script covers only Phases 1 & 2 (~40% of the documented pipeline). Phases 2.5 (consolidation), 3 (claims synthesis), 4 (verification), and 5 (report) exist only as prose in SKILL.md with zero automation. The SKILL.md promises a full pipeline the tool doesn't deliver.

---

## Correctness Findings

### Phase 1 — Transcript Extraction

| Severity | Issue |
|----------|-------|
| Note | `get_transcript_fetch_content()` always returns 1 — intentional but produces misleading "Trying..." output followed by immediate skip |
| Note | VTT cleanup AWK: timestamp regex `^[0-9][0-9]:[0-9][0-9]:` doesn't match single-digit-hour timestamps (`0:05:30.000`). Minor transcript noise risk. |
| Note | URL parsing regex misses `youtube.com/shorts/` and `youtube.com/live/` formats. Script dies with "Could not extract video ID." |

### Phase 2 — Fabric Patterns

| Severity | Issue |
|----------|-------|
| Note | No validation that fabric outputs have meaningful content. If all 4 patterns produce placeholders, pipeline hands garbage to the LLM. |
| Note | `run_fabric()` reports line count even for empty output. Should warn on empty. |
| Note | Four independent fabric calls could run in parallel (`&` + `wait`) for up to 4x speedup. |
| Note | No timeout on fabric calls. If fabric hangs (API timeout, network stall), script hangs forever. |
| Note | No retry logic. Transient API error → that pattern's output is permanently lost. |

### Phase 2.5 — Consolidation

| Severity | Issue |
|----------|-------|
| Note | "Consensus strength" in `appearance count × consensus strength` is undefined. LLM must invent its own interpretation → inconsistent rankings. |
| Note | Weighting is underspecified. "Weight extract_principles and extract_patterns higher" — by how much? Ad-hoc judgment reduces reproducibility. |
| Note | 15–25 concept target not mechanically enforced. |

### Phase 3 — Claims Synthesis

| Severity | Issue |
|----------|-------|
| Note | Concept→claim transformation is a pass-through with no added structure. A concept like "Always validate assumptions" and its claim are identical. No guidance on how a claim differs from a concept. |

### Phase 4 — Verification

| Severity | Issue |
|----------|-------|
| Note | "Authoritative" and "independent" are undefined. No criteria for source quality or independence. |
| Note | Parallel fan-out has no concurrency control. 20 claims fanning out simultaneously could overwhelm orchestrator or hit rate limits. |
| Note | Subagent tool requirement warns but doesn't solve — parent-session fallback is documented but not automated. |

---

## Gap Analysis

### Missing Edge Cases

- **Non-English or garbled transcripts** — no language detection. Pipeline silently produces garbage.
- **Very long transcripts** exceeding fabric context window — no truncation or chunking strategy.
- **youtube.com/shorts/** and **youtube.com/live/** URL formats not parsed.
- **fabric API key exhausted** or rate-limited — no detection.

### Missing Failure Documentation

SKILL.md Failure Modes table doesn't cover:
- Fabric API key exhausted or rate-limited
- Very long transcript exceeding fabric context window
- Non-English or garbled transcript → meaningless outputs
- Partial transcript (yt-dlp only getting first portion of long videos)
- Disk space exhaustion from Playwright Chromium install
- Network timeout during fabric calls

### Reliability

- **No signal handling** — no `trap` for SIGINT/SIGTERM. Partially-downloaded Chromium (~500MB) orphaned on ^C.
- **No temp file cleanup** — yt-dlp may create `.info.json` and `.part` files that are never cleaned up.
- **Speaker count heuristic** is fragile — `^[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?:` almost always returns 0 for auto-generated transcripts.

### Design Concerns

- **`setup_cookies` installs Firefox** — a transcript extraction script should not install browsers. Should fail with a clear error.
- **Playwright is extremely heavy** (~500MB install) for a 5th-tier fallback. Probability of reaching it is near-zero. Consider removing or making opt-in only.
- **`get_transcript_fetch_content()` is dead code dressed as functionality** — always returns 1, never extracts anything. Misleading.

### Missing UX

- No `--help` flag
- No `--output-dir` flag (only `OUTPUT_BASE` env var)
- No `--dry-run` flag to validate setup without spending API credits
- No transcript caching by video ID

### Missing Extraction Angles

- **extract_questions** — what questions does the speaker pose/answer?
- **extract_contradictions** — internal tensions in the speaker's argument
- **extract_frameworks** — structured step-by-step frameworks

---

## Summary

| Category | Count |
|----------|-------|
| 🔴 Critical | 2 |
| 🟡 Medium | 9 |
| 🔵 Low | 14 |
| **Total** | **25** |

The pipeline is well-architected for its core competency (transcript → multi-angle pattern extraction) but promises more automation than it delivers. The documentation is stronger than the tooling. Addressing B1 (exit code) and implementing automation for Phases 2.5–5 would bring the tool in line with its documentation.
