#!/usr/bin/env bash
# Runs every tests/test_*.sh, each in its own shell, and fails if any case failed.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
status=0
for t in "$here"/test_*.sh; do
    bash "$t" || status=1
done
exit "$status"
