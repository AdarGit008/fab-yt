---
name: fab-yt
description: "Extract claims from YouTube videos, verify them, and report findings. Trigger: /fab-yt <youtube-link>"
---

# /fab-yt — YouTube → Fabric → Verified Claims

Extract a YouTube transcript, run it through fabric patterns, synthesize claims,
verify each claim with web research, and report surviving claims.

## Prerequisites

- `fabric` CLI: `~/.local/bin/fabric` (or on PATH)
- `yt-dlp`, `youtube-transcript-api`: auto-installed if missing
- Playwright + Chromium: auto-installed if needed (tertiary fallback; skip with `SKIP_PLAYWRIGHT=1`)
- A browser with YouTube login: yt-dlp auto-detects Chrome/Firefox/Brave/Edge/Opera cookies on all platforms. No manual cookie export.

## Full Pipeline

Run the bash script for Phase 1-2, then handle Phase 3-5 via LLM:

```
./fab-yt.sh <youtube-url>
```

The script writes `OUTDIR` to stdout on the last line. Capture it.

### Phase 1 & 2 — Bash (fab-yt.sh)

```
1. Extract transcript → transcript.md
   - youtube-transcript-api (fast, no cookies, works on residential IPs)
   - fallback: yt-dlp with browser cookies (auto-detects Chrome/Firefox/Brave/Edge/Opera)
   - fallback: Playwright headless Chromium (anti-detection, works on blocked VPS IPs, auto-installs)
   - fallback: prompt user to install Firefox + log into YouTube
2. Run 3 fabric patterns: extract_wisdom, extract_insights, extract_instructions
3. Output: transcript.md, extract_wisdom.md, extract_insights.md, extract_instructions.md
```

### Phase 3 — Claims Synthesis (LLM)

Read the 3 fabric output files. Synthesize into simple, atomic claims.
Write `claims.md`:

```markdown
# Claims

## [Claim-1]
Single, verifiable factual claim. One fact per claim. No opinions.

## [Claim-2]
...
```

Rules:
- One fact per claim. Atomic — can't be split further.
- Drop duplicates and near-duplicates.
- Drop opinions, predictions, subjective statements that can't be verified.
- Drop vague/generic statements ("technology is important").
- Aim for 20-50 claims from the 3 fabric files. Quality over quantity.
- Tag each claim: `[Claim-N]`

### Phase 4 — Verification (Subagent Crews)

For EACH claim, run a research subagent. Use parallel fan-out for efficiency.

**Subagent task template:**
```
Verify this claim against web sources. Find exactly 3 independent,
authoritative sources. For each source, provide:
- The exact quote that supports or contradicts the claim
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
- **VERIFIED** — all 3/3 sources corroborate the claim. No contradictions.
- **UNDECIDED** — only 1-2/3 sources corroborate, or sources are ambiguous.
- **DISCARDED** — 0/3 sources support the claim, or all sources contradict.

Be tough but fair. A claim is only VERIFIED when 3 independent, authoritative sources agree.

### Phase 5 — Report

Write `verification.md` with all results, grouped by status:

```markdown
# Verification Report
**Video:** [URL]
**Date:** [date]
**Claims analyzed:** N
**VERIFIED:** V | **UNDECIDED:** U | **DISCARDED:** D

## ✅ VERIFIED
[verified claims with sources]

## 🤔 UNDECIDED
[undecided claims with sources]

## ❌ DISCARDED
[discarded claims with brief reason]
```

**Print to chat:**
```
## fab-yt Results

### ✅ VERIFIED (top 5)
- [Claim text] — [brief source note]

### 🤔 UNDECIDED (top 5)
- [Claim text] — [brief note on why]

### ❌ DISCARDED (all)
- [Claim text] — [reason]
```

## Failure Modes

| Problem | Action |
|---------|--------|
| `fab-yt.sh` not found | Clone the repo, ensure `chmod +x fab-yt.sh` |
| `fabric` not found | Install: `pip install fabric-ai` or check PATH |
| Transcript blocked | Script tries: 1) youtube-transcript-api, 2) yt-dlp with browser cookies, 3) Playwright headless (auto-installs ~500MB Chromium). Set `SKIP_PLAYWRIGHT=1` to skip the Playwright fallback. |
| Fabric pattern fails | Write a placeholder note in the output file |
| 0 claims survive | Report honestly — the video may not contain verifiable facts |
