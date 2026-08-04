#!/usr/bin/env bash
set -euo pipefail

# ─── fab-yt.sh ─── YouTube transcript → fabric patterns pipeline
# Usage: ./fab-yt.sh <youtube-url>
# Output: transcript.md, extract_wisdom.md, extract_insights.md, extract_instructions.md

# ─── config ───
FABRIC="${FABRIC:-fabric}"
YT_DLP="${YT_DLP:-yt-dlp}"
OUTPUT_BASE="${OUTPUT_BASE:-$HOME/pi_agent/projects/pi_research}"

# ─── helpers ───
die() { echo "❌ $1" >&2; exit 1; }
info() { echo "→ $1" >&2; }

# ─── parse args ───
URL="${1:-}"
[ -z "$URL" ] && die "Usage: fab-yt.sh <youtube-url>"
VIDEO_ID=$(echo "$URL" | sed -n 's/.*\(v=\|youtu\.be\/\|embed\/\)\([a-zA-Z0-9_-]\{11\}\).*/\2/p' | head -1)
[ -z "$VIDEO_ID" ] && die "Could not extract video ID from URL: $URL"

TIMESTAMP=$(date +%d-%m-%Y)
OUTDIR="$OUTPUT_BASE/fab-yt-$TIMESTAMP"
mkdir -p "$OUTDIR"

TRANSCRIPT="$OUTDIR/transcript.md"
WISDOM="$OUTDIR/extract_wisdom.md"
INSIGHTS="$OUTDIR/extract_insights.md"
INSTRUCTIONS="$OUTDIR/extract_instructions.md"

info "Video ID: $VIDEO_ID"
info "Output:   $OUTDIR"

# ═══════════════════════════════════════════
# PHASE 1: GET TRANSCRIPT
# ═══════════════════════════════════════════

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
    /^[0-9][0-9]:[0-9][0-9]:/ {next}
    /<[0-9][0-9]:/ {next}
    /<c>/ {next}
    /^align/ {next} /^position/ {next}
    /^[[:space:]]*$/ {next}
    { gsub(/^[[:space:]]+/, ""); gsub(/[[:space:]]+$/, "") }
    prev != $0 { print; prev = $0 }
    ' "$vtt_file"

    rm -f "$vtt_file" "$OUTDIR"/raw*.vtt
}



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

    # No browser with YouTube cookies. Guide user.
    if ! command -v firefox &>/dev/null; then
        info "Firefox not found. Installing..."
        if command -v apt-get &>/dev/null; then
            sudo apt-get install -y firefox 2>/dev/null || {
                info "No sudo. Installing Firefox locally..."
                curl -sL "https://download.mozilla.org/?product=firefox-latest&os=linux64&lang=en-US" -o /tmp/firefox.tar.xz
                tar xJf /tmp/firefox.tar.xz -C "$HOME/.local/" 2>/dev/null
                info "Firefox installed at $HOME/.local/firefox/firefox"
            }
        fi
    fi

    echo "" >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "║  YouTube blocked us. One-time auth needed.                  ║" >&2
    echo "║                                                            ║" >&2
    echo "║  Open Firefox, sign in to YouTube, visit any video.        ║" >&2
    echo "║  Then re-run. yt-dlp auto-detects cookies.                 ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    return 1
}

# ─── main transcript flow ───
info "Phase 1: Getting transcript..."

TRANSCRIPT_TEXT=""

# Attempt 1: youtube-transcript-api (fast, clean, no cookies)
info "Trying youtube-transcript-api..."
TRANSCRIPT_TEXT=$(get_transcript_api) && {
    echo "$TRANSCRIPT_TEXT" | wc -l >/dev/null
    [ -n "$(echo "$TRANSCRIPT_TEXT" | tr -d '[:space:]')" ] && info "✅ Got transcript via youtube-transcript-api"
} || TRANSCRIPT_TEXT=""

# Attempt 2: yt-dlp with cookies
if [ -z "$TRANSCRIPT_TEXT" ]; then
    info "youtube-transcript-api failed. Trying yt-dlp with cookies..."
    setup_cookies || die "Cannot proceed without authentication. Please set up cookies."
    TRANSCRIPT_TEXT=$(get_transcript_ytdlp) && {
        [ -n "$(echo "$TRANSCRIPT_TEXT" | tr -d '[:space:]')" ] && info "✅ Got transcript via yt-dlp"
    } || TRANSCRIPT_TEXT=""
fi



[ -z "$TRANSCRIPT_TEXT" ] && die "All transcript methods failed."

# ─── count speakers (crude heuristic: look for "Speaker:" or "[Name]:" patterns) ───
SPEAKER_COUNT=$(echo "$TRANSCRIPT_TEXT" | grep -oP '^[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?:' | sort -u | wc -l)

# ─── write transcript ───
{
    echo "# Transcript: $(echo "$URL" | cut -c1-80)"
    echo ""
    echo "**Video ID:** \`$VIDEO_ID\`  "
    echo "**Date:** $(date +%Y-%m-%d)  "
    echo "**Speakers detected:** $SPEAKER_COUNT"
    echo ""
    echo "---"
    echo ""
    echo "$TRANSCRIPT_TEXT"
} > "$TRANSCRIPT"
info "Transcript saved: $TRANSCRIPT ($(wc -l < "$TRANSCRIPT") lines)"

# ═══════════════════════════════════════════
# PHASE 2: FABRIC PATTERNS
# ═══════════════════════════════════════════

info "Phase 2: Running fabric patterns..."

run_fabric() {
    local pattern="$1"
    local output="$2"
    info "  → fabric -p $pattern"
    "$FABRIC" -p "$pattern" -o "$output" < "$TRANSCRIPT" 2>/dev/null && {
        info "  ✅ $output ($(wc -l < "$output") lines)"
    } || {
        echo "# $pattern failed" > "$output"
        info "  ⚠️  $pattern failed, wrote placeholder"
    }
}

run_fabric "extract_wisdom" "$WISDOM"
run_fabric "extract_insights" "$INSIGHTS"
run_fabric "extract_instructions" "$INSTRUCTIONS"

# ─── summary ───
echo ""
echo "╔══════════════════════════════════════╗"
echo "║  fab-yt Phase 1-2 complete           ║"
echo "╠══════════════════════════════════════╣"
echo "║  $TRANSCRIPT"
echo "║  $WISDOM"
echo "║  $INSIGHTS"
echo "║  $INSTRUCTIONS"
echo "╚══════════════════════════════════════╝"
echo ""
echo "OUTDIR=$OUTDIR"
