# fab-yt

YouTube → Fabric → Verified Claims

Extracts transcripts from YouTube videos, runs them through [fabric](https://github.com/danielmiessler/fabric) patterns (by Daniel Miessler), synthesizes claims, and verifies each claim against web sources using AI subagents.

## Pipeline

```
YouTube URL
    │
    ▼
transcript.md        ← youtube-transcript-api / yt-dlp / Playwright
    │
    ├── fabric extract_wisdom    → extract_wisdom.md
    ├── fabric extract_insights  → extract_insights.md
    └── fabric extract_instructions → extract_instructions.md
    │
    ▼
claims.md            ← LLM synthesizes, deduplicates
    │
    ▼
verification.md      ← Subagent crews verify each claim (3 sources)
    │
    ▼
Chat report          ← Top VERIFIED / UNDECIDED / DISCARDED
```

## Prerequisites

- `fabric` CLI (by [Daniel Miessler](https://github.com/danielmiessler/fabric))
- `youtube-transcript-api` or `yt-dlp` (auto-installed if missing)
- A browser with YouTube login (Chrome/Firefox/Brave/Edge/Opera — auto-detected)
- Playwright + Chromium (auto-installed on first use as tertiary fallback; set `SKIP_PLAYWRIGHT=1` to skip)

## Usage

```
/fab-yt https://www.youtube.com/watch?v=...
```

### Manual (CLI)

```bash
./fab-yt.sh "https://www.youtube.com/watch?v=..."
# Then follow LLM instructions for phases 3-5
```

## Output Structure

```
~/pi_agent/projects/pi_research/fab-yt-DD-MM-YYYY/
├── transcript.md
├── extract_wisdom.md
├── extract_insights.md
├── extract_instructions.md
├── claims.md
└── verification.md
```

## Verification Tiers

| Tier | Sources | Meaning |
|------|---------|---------|
| ✅ VERIFIED | 3/3 corroborate | Claim survives |
| 🤔 UNDECIDED | 1-2/3 corroborate | Insufficient evidence |
| ❌ DISCARDED | 0/3 corroborate | Claim rejected |

## Credits

- **fabric** patterns by [Daniel Miessler](https://github.com/danielmiessler/fabric)
- **yt-dlp** by the yt-dlp contributors
- **youtube-transcript-api** by jdepoix
- **Playwright** by Microsoft

## Extraction Methods (tried in order)

| # | Method | Requirements | Works on VPS? |
|---|--------|-------------|---------------|
| 1 | `youtube-transcript-api` | Python package | ❌ Often blocked |
| 2 | `yt-dlp` + browser cookies | Logged-in browser | ❌ Needs display |
| 3 | **Playwright headless** | Auto-installs Chromium (~500MB) | ✅ Yes |
