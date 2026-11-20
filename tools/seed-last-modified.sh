#!/usr/bin/env bash
# Writes a .last-modified/<path> entry for every tracked data/**/*.xml file,
# from the date of the last commit that touched it.
#
# CI (HistoryAtState/ci-actions last-mod.yml) only updates the entries of files
# a branch changes, so this seeds the rest once. It writes the same format as
# that workflow:
#
#   <?xml version="1.0" encoding="UTF-8"?>
#   <last-modified xml:id="data0x2F…" seconds_since_epoch="…">2026-10-28T03:01:28Z</last-modified>
#
# Dates are in UTC, as on the CI runner. One pass over the history, so it
# takes seconds rather than one git log per file.
#
# Usage: tools/seed-last-modified.sh   (from the repository root)

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

TZ=UTC git log --format='>%ct|%cd' --date=iso-strict-local --name-only -- 'data/*.xml' \
| awk '
    /^>/ { split(substr($0, 2), d, "|"); seconds = d[1]; datetime = d[2]; next }
    /^$/ { next }
    !($0 in seen) {
        seen[$0] = 1
        print seconds "\t" datetime "\t" $0
    }
' \
| while IFS=$'\t' read -r seconds datetime file; do
    # a file deleted since its last change has no entry
    [ -f "$file" ] || continue
    out=".last-modified/$file"
    # files arrive grouped by directory: create each one once
    if [ "${out%/*}" != "${dir:-}" ]; then
        dir=${out%/*}
        mkdir -p "$dir"
    fi
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<last-modified xml:id="%s" seconds_since_epoch="%s">%s</last-modified>\n' \
        "${file//\//0x2F}" "$seconds" "$datetime" > "$out"
done
