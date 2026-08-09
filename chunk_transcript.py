#!/usr/bin/env python3
"""Token-aware transcript chunking for fab-yt pipeline.

Uses Chonkie to split long transcripts into chunks that fit within fabric's
context window (~8K tokens). Maintains sentence boundaries for coherence.

Usage:
    python3 chunk_transcript.py < transcript.md
    python3 chunk_transcript.py transcript.md
    python3 chunk_transcript.py transcript.md --max-tokens 6000 --overlap 200
"""

import sys
import argparse

try:
    from chonkie import SentenceChunker
except ImportError:
    print("Chonkie not installed. Install: pip install chonkie", file=sys.stderr)
    sys.exit(1)


def chunk_transcript(text: str, max_tokens: int = 8000, overlap: int = 300) -> list[str]:
    """Split transcript into token-aware chunks at sentence boundaries."""
    chunker = SentenceChunker(
        tokenizer="gpt2",
        chunk_size=max_tokens,
        chunk_overlap=overlap,
    )
    chunks = chunker.chunk(text)
    return [chunk.text for chunk in chunks]


def main():
    parser = argparse.ArgumentParser(
        description="Token-aware transcript chunking for fab-yt pipeline"
    )
    parser.add_argument(
        "file", nargs="?", default="-",
        help="Transcript file (default: stdin)"
    )
    parser.add_argument(
        "--max-tokens", type=int, default=8000,
        help="Max tokens per chunk (default: 8000)"
    )
    parser.add_argument(
        "--overlap", type=int, default=300,
        help="Token overlap between chunks (default: 300)"
    )
    parser.add_argument(
        "--output-dir", default=".",
        help="Directory for chunk output files"
    )
    args = parser.parse_args()

    # Read input
    if args.file == "-":
        text = sys.stdin.read()
    else:
        with open(args.file) as f:
            text = f.read()

    if not text.strip():
        print("Empty transcript — nothing to chunk.", file=sys.stderr)
        sys.exit(0)

    chunks = chunk_transcript(text, max_tokens=args.max_tokens, overlap=args.overlap)

    if len(chunks) <= 1:
        # Single chunk — no chunking needed. Output as-is.
        print(text)
        return

    # Write numbered chunks
    import os
    base = os.path.splitext(os.path.basename(args.file))[0] if args.file != "-" else "transcript"
    out_dir = args.output_dir

    print(f"Split into {len(chunks)} chunks (max {args.max_tokens} tokens, {args.overlap} overlap)", file=sys.stderr)

    for i, chunk in enumerate(chunks, 1):
        chunk_file = os.path.join(out_dir, f"{base}_chunk_{i:02d}.md")
        with open(chunk_file, "w") as f:
            f.write(f"# Transcript Chunk {i}/{len(chunks)}\n\n")
            f.write(chunk)
        print(f"  Chunk {i}: {chunk_file} ({len(chunk)} chars)", file=sys.stderr)

    print(f"\nRun fabric on each chunk, then consolidate.", file=sys.stderr)
    print(f"Chunks written to: {out_dir}/", file=sys.stderr)


if __name__ == "__main__":
    main()
