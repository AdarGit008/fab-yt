# fab-yt

YouTube → Fabric → Verified Concepts & Principles

Extracts transcripts from YouTube videos, runs them through [fabric](https://github.com/danielmiessler/fabric) patterns tuned for actionable concepts/guidelines/principles, cross-references outputs to surface the most-iterated ideas, and verifies each one against web sources using AI subagents.

## Pipeline

```
YouTube URL
    │
    ▼
transcript.md              ← fabric --youtube / youtube-transcript-api / yt-dlp / Playwright
    │
    ├── extract_patterns       → recurring concepts
    ├── extract_ideas          → all ideas
    ├── extract_recommendations → actionable items
    └── extract_principles     → principles & guidelines (custom pattern)
    │
    ▼
consolidation.md            ← LLM cross-references 4 outputs, ranks by iteration count
    │
    ▼
claims.md                   ← Top N most-iterated concepts become claims
    │
    ▼
verification.md             ← Subagent crews verify each claim (3 sources)
    │
    ▼
Chat report                 ← VERIFIED / UNDECIDED / DISCARDED
```

### Why this pipeline?

The old pipeline used `extract_wisdom` which extracted "facts about the greater world" — dates, places, events. These trivia claims wasted tokens during verification and provided zero actionable value.

The new pipeline is tuned for **concepts, guidelines, and principles** — things you can actually use. The consolidation step (Phase 2.5) cross-references all 4 fabric outputs to find ideas that appear repeatedly, surfacing the most important concepts while discarding noise.

## Prerequisites

- `fabric` CLI v1.4.459+ (by [Daniel Miessler](https://github.com/danielmiessler/fabric)) — includes built-in YouTube transcript extraction
- `youtube-transcript-api` or `yt-dlp` (auto-installed if missing)
- A browser with YouTube login (Chrome/Firefox/Brave/Edge/Opera — auto-detected)
- Playwright + Chromium (auto-installed on first use as tertiary fallback; set `SKIP_PLAYWRIGHT=1` to skip)

## Setup

```bash
# Install the custom extract_principles pattern
mkdir -p ~/.config/fabric/patterns/extract_principles
cp patterns/extract_principles/system.md ~/.config/fabric/patterns/extract_principles/system.md
```

## Usage

```
/fab-yt https://www.youtube.com/watch?v=...
```

### Manual (CLI)

```bash
./fab-yt.sh "https://www.youtube.com/watch?v=..."
# Then follow LLM instructions for phases 2.5-5
```

## Output Structure

```
~/pi_agent/projects/pi_research/fab-yt-DD-MM-YYYY/
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

## Extraction Methods (tried in order)

| # | Method | Requirements | Works on VPS? |
|---|--------|-------------|---------------|
| 0 | `fabric --youtube` | fabric v1.4.459+ | ✅ Yes |
| 1 | `youtube-transcript-api` | Python package | ❌ Often blocked |
| 2 | `yt-dlp` + browser cookies | Logged-in browser | ❌ Needs display |
| 3 | **Playwright headless** | Auto-installs Chromium (~500MB) | ✅ Yes |
