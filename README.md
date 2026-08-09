# fab-yt

YouTube → Fabric → Verified Concepts & Principles

Extracts transcripts from YouTube videos, runs them through [fabric](https://github.com/danielmiessler/fabric) patterns tuned for actionable concepts/guidelines/principles, cross-references outputs to surface the most-iterated ideas, and verifies each one against web sources using AI subagents.

## Pipeline

```
YouTube URL
    │
    ▼
transcript.md              ← fabric --youtube / youtube-transcript-api / yt-dlp
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
- `chonkie` Python package for token-aware transcript chunking: `pip install chonkie`
- A browser with YouTube login (Chrome/Firefox/Brave/Edge/Opera — auto-detected)

> **⚠️ English only.** This pipeline is designed for English-language transcripts. YouTube auto-captions in other languages, garbled transcripts, or multi-language videos will produce meaningless results. Check transcript language before running.

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
# Phase 1-2: Extract transcript + run fabric patterns
./fab-yt.sh "https://www.youtube.com/watch?v=..."

# Phase 2.5-5: Generate LLM prompt templates
./fab-yt-llm.sh ~/pi_agent/projects/pi_research/fab-yt-DD-MM-YYYY-NN/

# Optional: Chunk long transcripts before fabric
python3 chunk_transcript.py transcript.md --max-tokens 6000
```

### CLI Flags

```
-t, --transcript FILE  Use provided transcript (use '-' for stdin)
-o, --output-dir DIR   Override output directory (default: ~/pi_agent/projects/pi_research)
--dry-run              Validate setup without extracting or spending API credits
-h, --help             Show help message
```

## Output Structure

```
~/pi_agent/projects/pi_research/fab-yt-DD-MM-YYYY-NN/
├── transcript.md
├── extract_patterns.md
├── extract_ideas.md
├── extract_recommendations.md
├── extract_principles.md
├── prompt_consolidation.md   ← fab-yt-llm.sh output
├── prompt_claims.md
├── prompt_verification.md
├── prompt_report.md
├── consolidation.md
├── claims.md
├── verification.md
└── report.md
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

## Extraction Methods (tried in order)

| # | Method | Requirements | Works on VPS? |
|---|--------|-------------|---------------|
| 0 | `fabric --youtube` | fabric v1.4.459+ | ✅ Yes |
| 1 | `youtube-transcript-api` | Python package | ❌ Often blocked |
| 2 | `yt-dlp` + browser cookies | Logged-in browser | ❌ Needs display |
| 3 | **fetch_content** (Pi tool) | Pi agent with Gemini | ✅ Yes |
