#!/usr/bin/env bash
set -euo pipefail

# ─── fab-yt.sh ─── YouTube transcript → fabric patterns pipeline
# Usage: ./fab-yt.sh [--transcript <file>] <youtube-url>
#        ./fab-yt.sh --transcript - <youtube-url>   (stdin)
#        ./fab-yt.sh --transcript file.md            (URL optional)
# Output: transcript.md + 4 fabric pattern outputs (concepts/guidelines/principles focus)

# ─── config ───
FABRIC="${FABRIC:-fabric}"
YT_DLP="${YT_DLP:-yt-dlp}"
OUTPUT_BASE="${OUTPUT_BASE:-$HOME/pi_agent/projects/pi_research}"

# ─── helpers ───
die() { echo "❌ $1" >&2; exit 1; }
info() { echo "→ $1" >&2; }

# ─── preflight checks ───
if ! command -v timeout &>/dev/null; then
    die "'timeout' command not found. Install coreutils (apt install coreutils / brew install coreutils)"
fi

# ─── parse args ───
TRANSCRIPT_FILE=""
URL=""
DRY_RUN=0
while [ $# -gt 0 ]; do
    case "$1" in
        -t|--transcript)
            TRANSCRIPT_FILE="${2:-}"
            [ -z "$TRANSCRIPT_FILE" ] && die "--transcript requires a file path (or '-' for stdin)"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_BASE="${2:-}"
            [ -z "$OUTPUT_BASE" ] && die "--output-dir requires a directory path"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            cat <<'HELP'
Usage: fab-yt.sh [OPTIONS] <youtube-url>
       fab-yt.sh --transcript <file> [youtube-url]

YouTube transcript → fabric patterns pipeline.

Options:
  -t, --transcript FILE  Use provided transcript (use '-' for stdin)
  -o, --output-dir DIR   Override output directory (default: ~/pi_agent/projects/pi_research)
  --dry-run              Validate setup without extracting or spending API credits
  -h, --help             Show this help message

Environment:
  FABRIC        Path to fabric CLI (default: fabric)
  YT_DLP        Path to yt-dlp (default: yt-dlp)
  OUTPUT_BASE   Base output directory (default: ~/pi_agent/projects/pi_research)
HELP
            exit 0
            ;;
        -*)
            die "Unknown flag: $1. Use --help for usage."
            ;;
        *)
            URL="$1"
            shift
            ;;
    esac
done
if [ "$DRY_RUN" -eq 0 ]; then
    [ -z "$TRANSCRIPT_FILE" ] && [ -z "$URL" ] && die "Usage: fab-yt.sh [--transcript <file>] <youtube-url>. Use --help for details."
fi
if [ -n "$URL" ]; then
    VIDEO_ID=$(echo "$URL" | sed -n 's/.*\(v=\|youtu\.be\/\|embed\/\|shorts\/\|live\/\)\([a-zA-Z0-9_-]\{11\}\).*/\2/p' | head -1)
    [ -z "$VIDEO_ID" ] && die "Could not extract video ID from URL: $URL"
else
    VIDEO_ID="manual"
    URL="(transcript provided manually)"
fi

TIMESTAMP=$(date +%d-%m-%Y)
SERIAL=1
while [ -d "$OUTPUT_BASE/fab-yt-$TIMESTAMP-$(printf '%02d' "$SERIAL")" ]; do
    SERIAL=$((SERIAL + 1))
done
SERIAL_FMT=$(printf '%02d' "$SERIAL")
OUTDIR="$OUTPUT_BASE/fab-yt-$TIMESTAMP-$SERIAL_FMT"
[ "$DRY_RUN" -eq 0 ] && mkdir -p "$OUTDIR"

TRANSCRIPT="$OUTDIR/transcript.md"
PATTERNS="$OUTDIR/extract_patterns.md"
IDEAS="$OUTDIR/extract_ideas.md"
RECOMMENDATIONS="$OUTDIR/extract_recommendations.md"
PRINCIPLES="$OUTDIR/extract_principles.md"

info "Video ID: $VIDEO_ID"
info "Output:   $OUTDIR"

# ═══════════════════════════════════════════
# PHASE 1: GET TRANSCRIPT
# ═══════════════════════════════════════════

get_transcript_fabric() {
    # fabric v1.4.459+ has built-in YouTube transcript extraction
    "$FABRIC" --youtube "$URL" --transcript 2>/dev/null
}

get_transcript_api() {
    # youtube-transcript-api (clean text, no parsing needed)
    python3 -c "
from youtube_transcript_api import YouTubeTranscriptApi
api = YouTubeTranscriptApi()
t = api.fetch('$VIDEO_ID')
for s in t:
    print(s.text)
" 2>/dev/null
}

get_transcript_ytdlp() {
    # yt-dlp with browser cookies → VTT → clean
    local args=(--skip-download --write-auto-subs --sub-format vtt --output "$OUTDIR/raw")
    [ -n "${COOKIE_BROWSER:-}" ] && args+=(--cookies-from-browser "$COOKIE_BROWSER")
    args+=("$URL")

    "$YT_DLP" "${args[@]}" >/dev/null 2>&1 || return 1

    # Find the VTT file (yt-dlp may name it differently)
    local vtt_file
    vtt_file=$(ls "$OUTDIR"/raw*.vtt 2>/dev/null | head -1)
    [ -z "$vtt_file" ] && return 1

    # Clean VTT: strip timestamps, tags, blank lines, dedupe adjacent
    awk '
    /^WEBVTT/ {next} /^Kind:/ {next} /^Language:/ {next}
    /^[0-9][0-9]?:[0-9][0-9]:/ {next}
    /<[0-9][0-9]?:/ {next}
    /<c>/ {next}
    /^align/ {next} /^position/ {next}
    /^[[:space:]]*$/ {next}
    { gsub(/^[[:space:]]+/, ""); gsub(/[[:space:]]+$/, "") }
    prev != $0 { print; prev = $0 }
    ' "$vtt_file"

    rm -f "$vtt_file" "$OUTDIR"/raw*.vtt
}

# ─── cleanup ───
cleanup() {
    info "Cleaning up temp files..."
    rm -f "$OUTDIR"/raw*.info.json "$OUTDIR"/raw*.part "$OUTDIR"/raw*.vtt 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ─── cookie setup ───
# yt-dlp --cookies-from-browser auto-detects Chrome/Firefox/Brave/Edge/Opera
# on Linux, macOS, and Windows. No custom extraction needed.
setup_cookies() {
    # Detect available browser for --cookies-from-browser
    for browser in firefox chrome chromium brave edge opera; do
        if "$YT_DLP" --cookies-from-browser "$browser" --skip-download -s "https://www.youtube.com" >/dev/null 2>&1; then
            info "Cookies detected from: $browser"
            COOKIE_BROWSER="$browser"
            return 0
        fi
    done

    echo "" >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "║  YouTube blocked us. One-time auth needed.                  ║" >&2
    echo "║                                                            ║" >&2
    echo "║  Sign in to YouTube in any browser (Firefox/Chrome/etc).   ║" >&2
    echo "║  Then re-run. yt-dlp auto-detects cookies.                 ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    return 1
}

# ─── dry-run ───
if [ "$DRY_RUN" -eq 1 ]; then
    info "Dry run — validating setup..."
    command -v "$FABRIC" >/dev/null 2>&1 || die "fabric not found. Install: pip install fabric-ai"
    info "✅ fabric: $(command -v "$FABRIC")"
    command -v "$YT_DLP" >/dev/null 2>&1 || info "⚠️  yt-dlp not found (optional, for cookie-based fallback)"
    python3 -c "import youtube_transcript_api" 2>/dev/null && info "✅ youtube-transcript-api available" || info "⚠️  youtube-transcript-api not installed (optional)"
    [ -n "$URL" ] && info "Would extract: $URL"
    [ -n "$TRANSCRIPT_FILE" ] && info "Would use transcript: $TRANSCRIPT_FILE"
    info "Dry run complete. Setup looks OK."
    exit 0
fi

# ─── main transcript flow ───
if [ -n "$TRANSCRIPT_FILE" ]; then
    # ─── Phase 1 (skip): Use provided transcript ───
    info "Phase 1: Using provided transcript..."
    if [ "$TRANSCRIPT_FILE" = "-" ]; then
        info "Reading transcript from stdin..."
        # Check stdin is not empty before blocking on cat
        if [ -t 0 ]; then
            die "--transcript - requires stdin data (pipe or redirect)"
        fi
        TRANSCRIPT_TEXT=$(cat)
    else
        [ -f "$TRANSCRIPT_FILE" ] || die "Transcript file not found: $TRANSCRIPT_FILE"
        info "Reading transcript: $TRANSCRIPT_FILE"
        TRANSCRIPT_TEXT=$(cat "$TRANSCRIPT_FILE")
    fi
    [ -n "$(echo "$TRANSCRIPT_TEXT" | tr -d '[:space:]')" ] || die "Provided transcript is empty."
    info "✅ Got transcript via --transcript"
else
    # ─── Phase 1: Extract transcript ───
    info "Phase 1: Getting transcript..."

    TRANSCRIPT_TEXT=""

    # Attempt 0: fabric built-in YouTube (v1.4.459+, uses yt-dlp internally)
    info "Trying fabric built-in YouTube transcript..."
    TRANSCRIPT_TEXT=$(get_transcript_fabric) && {
        [ -n "$(echo "$TRANSCRIPT_TEXT" | tr -d '[:space:]')" ] && info "✅ Got transcript via fabric --youtube"
    } || TRANSCRIPT_TEXT=""

    # Attempt 1: youtube-transcript-api (fast, clean, no cookies)
    if [ -z "$TRANSCRIPT_TEXT" ]; then
        info "fabric --youtube failed. Trying youtube-transcript-api..."
        TRANSCRIPT_TEXT=$(get_transcript_api) && {
            echo "$TRANSCRIPT_TEXT" | wc -l >/dev/null
            [ -n "$(echo "$TRANSCRIPT_TEXT" | tr -d '[:space:]')" ] && info "✅ Got transcript via youtube-transcript-api"
        } || TRANSCRIPT_TEXT=""
    fi

    # Attempt 2: yt-dlp with browser cookies
    if [ -z "$TRANSCRIPT_TEXT" ]; then
        info "youtube-transcript-api failed. Trying yt-dlp with cookies..."
        if setup_cookies; then
            TRANSCRIPT_TEXT=$(get_transcript_ytdlp) && {
                [ -n "$(echo "$TRANSCRIPT_TEXT" | tr -d '[:space:]')" ] && info "✅ Got transcript via yt-dlp"
            } || TRANSCRIPT_TEXT=""
        fi
    fi

    if [ -z "$TRANSCRIPT_TEXT" ]; then
        info "⚠️  All transcript CLI methods failed."
        touch "$OUTDIR/.transcript_failed"
        {
            echo "# Transcript extraction failed"
            echo ""
            echo "**Video ID:** \`$VIDEO_ID\`"
            echo "**URL:** $URL"
            echo ""
            echo "All extraction methods failed."
            echo ""
            echo "Copy the transcript from YouTube's UI (••• → Show transcript)"
            echo "and save it to this file, then re-run:"
            echo "\`\`\`"
            echo "./fab-yt.sh --transcript $TRANSCRIPT"
            echo "\`\`\`"
        } > "$TRANSCRIPT"
        info "Transcript failure marker: $TRANSCRIPT"
        echo ""
        echo "╔══════════════════════════════════════╗"
        echo "║  ⚠️  Transcript extraction FAILED    ║"
        echo "╠══════════════════════════════════════╣"
        echo "║  All methods failed.                 ║"
        echo "║  Copy transcript from YouTube UI     ║"
        echo "║  then: fab-yt.sh --transcript FILE   ║"
        echo "╠══════════════════════════════════════╣"
        echo "║  $TRANSCRIPT"
        echo "╚══════════════════════════════════════╝"
        echo ""
        echo "OUTDIR=$OUTDIR"
        echo "TRANSCRIPT_FAILED=1"
        exit 1
    fi
fi

# ─── write transcript ───
{
    echo "# Transcript: $(echo "$URL" | cut -c1-80)"
    echo ""
    echo "**Video ID:** \`$VIDEO_ID\`  "
    echo "**Date:** $(date +%Y-%m-%d)  "
    [ -n "$TRANSCRIPT_FILE" ] && echo "**Source:** provided via --transcript"
    echo ""
    echo "---"
    echo ""
    echo "$TRANSCRIPT_TEXT"
} > "$TRANSCRIPT"
info "Transcript saved: $TRANSCRIPT ($(wc -l < "$TRANSCRIPT") lines)"

# ═══════════════════════════════════════════
# PHASE 2: FABRIC PATTERNS
# ═══════════════════════════════════════════
# Focus: concepts, guidelines, principles — NOT trivia/dates/events.
# Patterns chosen to surface recurring, actionable ideas from multiple angles.

info "Phase 2: Running fabric patterns (concepts/guidelines/principles focus)..."

run_fabric() {
    local pattern="$1"
    local output="$2"
    local label="$3"
    local max_retries=3
    local attempt=1

    # Timeout based on transcript size (~2s per 1K chars, min 30s, max 300s)
    local transcript_chars
    transcript_chars=$(wc -c < "$TRANSCRIPT")
    local timeout_sec=$(( transcript_chars / 500 ))
    [ "$timeout_sec" -lt 30 ] && timeout_sec=30
    [ "$timeout_sec" -gt 300 ] && timeout_sec=300

    while [ $attempt -le $max_retries ]; do
        info "  → fabric -p $pattern ($label) [attempt $attempt/$max_retries, timeout ${timeout_sec}s]"
        if timeout "$timeout_sec" "$FABRIC" -p "$pattern" -o "$output" < "$TRANSCRIPT" 2>/dev/null; then
            local lines
            lines=$(wc -l < "$output")
            if [ ! -s "$output" ]; then
                info "  ⚠️  $pattern output empty (0 bytes), attempt $attempt/$max_retries"
                attempt=$((attempt + 1))
                continue
            fi
            info "  ✅ $output ($lines lines)"
            return 0
        else
            info "  ⚠️  $pattern failed (exit=$?), attempt $attempt/$max_retries"
            attempt=$((attempt + 1))
            sleep $((2 ** (attempt - 1)))  # exponential backoff: 1s, 2s, 4s
        fi
    done

    # All retries exhausted
    echo "# $pattern failed after $max_retries attempts" > "$output"
    info "  ❌ $pattern failed after $max_retries attempts, wrote placeholder"
    return 1
}

run_fabric "extract_patterns"      "$PATTERNS"       "recurring concepts" &
run_fabric "extract_ideas"         "$IDEAS"          "all ideas" &
run_fabric "extract_recommendations" "$RECOMMENDATIONS" "actionable items" &
run_fabric "extract_principles"    "$PRINCIPLES"     "principles & guidelines" &
wait

# ─── fabric output validation ───
FABRIC_OK=0
FABRIC_FAILED=0
for f in "$PATTERNS" "$IDEAS" "$RECOMMENDATIONS" "$PRINCIPLES"; do
    if [ -f "$f" ] && [ -s "$f" ]; then
        FABRIC_OK=$((FABRIC_OK + 1))
    else
        FABRIC_FAILED=$((FABRIC_FAILED + 1))
    fi
done
if [ "$FABRIC_OK" -eq 0 ]; then
    die "All 4 fabric patterns produced empty output. Pipeline cannot continue."
fi
if [ "$FABRIC_FAILED" -gt 0 ]; then
    info "⚠️  $FABRIC_FAILED/4 fabric pattern(s) produced empty output."
fi

# ─── summary ───
echo ""
echo "╔══════════════════════════════════════╗"
echo "║  fab-yt Phase 1-2 complete           ║"
echo "╠══════════════════════════════════════╣"
echo "║  $TRANSCRIPT"
echo "║  $PATTERNS"
echo "║  $IDEAS"
echo "║  $RECOMMENDATIONS"
echo "║  $PRINCIPLES"
echo "╠══════════════════════════════════════╣"
echo "║  Next: Phase 2.5 — Consolidation     ║"
echo "║  (LLM cross-references all 4 files)   ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "OUTDIR=$OUTDIR"
