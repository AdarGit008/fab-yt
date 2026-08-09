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
while [ $# -gt 0 ]; do
    case "$1" in
        -t|--transcript)
            TRANSCRIPT_FILE="${2:-}"
            [ -z "$TRANSCRIPT_FILE" ] && die "--transcript requires a file path (or '-' for stdin)"
            shift 2
            ;;
        -*)
            die "Unknown flag: $1"
            ;;
        *)
            URL="$1"
            shift
            ;;
    esac
done
[ -z "$TRANSCRIPT_FILE" ] && [ -z "$URL" ] && die "Usage: fab-yt.sh [--transcript <file>] <youtube-url>"
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
mkdir -p "$OUTDIR"

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

# ─── Playwright headless Chromium (anti-detection, no login needed) ───
# Skip with SKIP_PLAYWRIGHT=1 to avoid the ~500MB Chromium install.
ensure_playwright() {
    if python3 -c "import playwright" 2>/dev/null; then
        return 0
    fi
    info "Installing Playwright + Chromium (one-time, ~500MB)..."
    pip install playwright --quiet 2>/dev/null || {
        info "⚠️  pip install playwright failed. Try: pip install playwright"
        return 1
    }
    python3 -m playwright install chromium --with-deps 2>/dev/null || {
        info "⚠️  playwright install chromium failed. Try: python3 -m playwright install chromium"
        return 1
    }
    info "✅ Playwright + Chromium installed."
    return 0
}

get_transcript_playwright() {
    # Headless Chromium → click "Show transcript" → extract text
    python3 -c "
from playwright.sync_api import sync_playwright
import sys

VIDEO_ID = '$VIDEO_ID'
URL = f'https://www.youtube.com/watch?v={VIDEO_ID}'

ANTI_DETECTION = '''
    Object.defineProperty(navigator, 'webdriver', {get: () => undefined});
    window.chrome = { runtime: {}, loadTimes: function(){}, csi: function(){} };
    Object.defineProperty(navigator, 'plugins', {get: () => [1, 2, 3, 4, 5]});
    Object.defineProperty(navigator, 'languages', {get: () => ['en-US', 'en']});
    const origQuery = window.navigator.permissions.query;
    window.navigator.permissions.query = (params) => (
        params.name === 'notifications' ?
            Promise.resolve({state: Notification.permission}) :
            origQuery(params)
    );
'''

with sync_playwright() as p:
    browser = p.chromium.launch(
        headless=True,
        args=[
            '--disable-blink-features=AutomationControlled',
            '--disable-features=IsolateOrigins,site-per-process',
            '--no-sandbox', '--disable-setuid-sandbox',
            '--disable-dev-shm-usage', '--disable-accelerated-2d-canvas',
            '--no-first-run', '--no-zygote', '--disable-gpu',
        ]
    )
    ctx = browser.new_context(
        viewport={'width': 1920, 'height': 1080},
        user_agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'
    )
    ctx.add_init_script(ANTI_DETECTION)
    page = ctx.new_page()

    try:
        page.goto(URL, wait_until='domcontentloaded', timeout=30000)
        page.wait_for_timeout(3000)

        # Click 'Show transcript' — try multiple selector strategies
        clicked = False
        selectors = [
            'button[aria-label*=\"Show transcript\" i]',
            'button[aria-label*=\"Transcript\" i]',
            'ytd-button-renderer:has-text(\"Transcript\") button',
            '#primary-button button[aria-label*=\"transcript\" i]',
        ]
        for sel in selectors:
            try:
                btn = page.wait_for_selector(sel, timeout=5000)
                if btn and btn.is_visible():
                    btn.click()
                    clicked = True
                    break
            except Exception:
                continue

        if not clicked:
            # Fallback: '...' menu → Transcript
            try:
                page.click('button[aria-label=\"More actions\"]', timeout=3000)
                page.wait_for_timeout(500)
                page.click('tp-yt-paper-item:has-text(\"Transcript\"), ytd-menu-service-item-renderer:has-text(\"Transcript\")', timeout=3000)
                clicked = True
            except Exception:
                pass

        if not clicked:
            sys.stderr.write('Playwright: transcript button not found\\n')
            sys.exit(1)

        # Wait for segments to render
        page.wait_for_selector('ytd-transcript-segment-renderer', timeout=10000)
        page.wait_for_timeout(1000)

        segments = page.query_selector_all('ytd-transcript-segment-renderer')
        if not segments:
            sys.stderr.write('Playwright: no transcript segments found\\n')
            sys.exit(1)

        for seg in segments:
            text_el = seg.query_selector('#content, .segment-text, yt-formatted-string')
            if text_el:
                line = text_el.inner_text().strip()
                if line:
                    print(line)

    except Exception as e:
        sys.stderr.write(f'Playwright error: {e}\\n')
        sys.exit(1)
    finally:
        browser.close()
"
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
if [ -n "$TRANSCRIPT_FILE" ]; then
    # ─── Phase 1 (skip): Use provided transcript ───
    info "Phase 1: Using provided transcript..."
    if [ "$TRANSCRIPT_FILE" = "-" ]; then
        info "Reading transcript from stdin..."
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
        else
            info "Cookie setup failed — will try Playwright fallback."
        fi
    fi

    # Attempt 3: Playwright headless Chromium (anti-detection, last resort)
    if [ -z "$TRANSCRIPT_TEXT" ]; then
        if [ "${SKIP_PLAYWRIGHT:-0}" = "1" ]; then
            info "SKIP_PLAYWRIGHT=1 — skipping Playwright fallback."
        elif ensure_playwright; then
            info "Trying Playwright headless Chromium (anti-detection)..."
            TRANSCRIPT_TEXT=$(get_transcript_playwright) && {
                [ -n "$(echo "$TRANSCRIPT_TEXT" | tr -d '[:space:]')" ] && info "✅ Got transcript via Playwright"
            } || TRANSCRIPT_TEXT=""
        else
            info "Playwright install failed — giving up."
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

# ─── count speakers (crude heuristic: look for "Speaker:" or "[Name]:" patterns) ───
SPEAKER_COUNT=$(echo "$TRANSCRIPT_TEXT" | grep -oP '^[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?:' | sort -u | wc -l)

# ─── write transcript ───
{
    echo "# Transcript: $(echo "$URL" | cut -c1-80)"
    echo ""
    echo "**Video ID:** \`$VIDEO_ID\`  "
    echo "**Date:** $(date +%Y-%m-%d)  "
    echo "**Speakers detected:** $SPEAKER_COUNT"
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
