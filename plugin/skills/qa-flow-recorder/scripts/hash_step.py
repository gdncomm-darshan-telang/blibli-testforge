#!/usr/bin/env python3
"""Per-step content hash for the qa-flow-recorder tracking doc's Step -> Test Mapping table.

Hashes are computed per test-case step (not per document), so a future re-run can report which
individual steps changed rather than treating the whole document as one blob. Whitespace is
normalized before hashing so a step's hash survives incidental re-wrapping/re-indentation of the
same wording (from re-pasting the same Confluence page or plain-English list) without flagging a
false change.

Usage:
    hash_step.py "Tap the search bar and enter a query"
    echo "Tap the search bar and enter a query" | hash_step.py

Output: the normalized SHA-256 hex digest, one line, on stdout.
"""
import re
import sys


def normalize(text: str) -> str:
    """Strip leading/trailing whitespace and collapse internal whitespace runs to a single space."""
    return re.sub(r"\s+", " ", text.strip())


def hash_step(text: str) -> str:
    import hashlib

    normalized = normalize(text)
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def main() -> None:
    if len(sys.argv) > 1:
        raw_text = " ".join(sys.argv[1:])
    else:
        raw_text = sys.stdin.read()

    if not normalize(raw_text):
        print("ERROR: empty step text after normalization", file=sys.stderr)
        sys.exit(1)

    print(hash_step(raw_text))


if __name__ == "__main__":
    main()
