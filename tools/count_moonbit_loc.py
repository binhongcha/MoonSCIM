#!/usr/bin/env python3
"""Count project-owned effective MoonBit lines with a reproducible policy."""

from __future__ import annotations

import argparse
from pathlib import Path


EXCLUDED_PARTS = {".git", ".mooncakes", ".scratch", "_build", "target"}


def moonbit_files(root: Path):
    for path in sorted(root.rglob("*.mbt")):
        if not EXCLUDED_PARTS.intersection(path.relative_to(root).parts):
            yield path


def count_effective(path: Path) -> tuple[int, int, int]:
    physical = nonempty = effective = 0
    in_block_comment = False
    for raw in path.read_text(encoding="utf-8").splitlines():
        physical += 1
        stripped = raw.strip()
        if stripped:
            nonempty += 1
        cursor = 0
        has_code = False
        while cursor < len(stripped):
            if in_block_comment:
                end = stripped.find("*/", cursor)
                if end < 0:
                    cursor = len(stripped)
                else:
                    in_block_comment = False
                    cursor = end + 2
            else:
                if stripped.startswith("//", cursor):
                    cursor = len(stripped)
                elif stripped.startswith("/*", cursor):
                    in_block_comment = True
                    cursor += 2
                elif stripped[cursor].isspace():
                    cursor += 1
                else:
                    has_code = True
                    cursor += 1
        if has_code:
            effective += 1
    return physical, nonempty, effective


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--minimum", type=int, default=0)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    totals = [0, 0, 0]
    files = list(moonbit_files(root))
    for path in files:
        counts = count_effective(path)
        totals = [left + right for left, right in zip(totals, counts)]
    print(f"MoonBit files: {len(files)}")
    print(f"Physical lines: {totals[0]}")
    print(f"Non-empty lines: {totals[1]}")
    print(f"Effective non-comment lines: {totals[2]}")
    if totals[2] < args.minimum:
        print(f"ERROR: expected at least {args.minimum} effective lines")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
