#!/usr/bin/env bash
# Runs the commit-msg hook over every commit in BASE..HEAD (env), inside a git checkout.
# Exit 0 when all pass, 1 otherwise. Home and rules: https://github.com/Jleeblanch/commit-check
set -euo pipefail

hook="$(dirname "$0")/commit-msg"
BASE="${BASE:-}"
HEAD="${HEAD:-}"

if [ -z "$BASE" ] || [ -z "$HEAD" ]; then
    echo "::error::no commit range to check: BASE or HEAD is empty. Run this on the pull_request event."
    exit 1
fi

# A shallow clone lacks the base, and a range git cannot read must fail, not pass as empty.
if ! git cat-file -e "$BASE^{commit}" 2>/dev/null || ! git cat-file -e "$HEAD^{commit}" 2>/dev/null \
    || [ "$(git rev-parse --is-shallow-repository)" = true ]; then
    echo "::error::the range's commits are not in this checkout. Set fetch-depth: 0 on actions/checkout."
    exit 1
fi

# Each on its own line, so a failing git call stops the script instead of yielding an empty list.
merges="$(git rev-list --merges "$BASE..$HEAD")"
shas="$(git rev-list --reverse --no-merges "$BASE..$HEAD")"

# The runner parses ::command:: text and a carriage return can start a fresh line, so no control
# character from a commit reaches the log. clean_lines keeps newlines (and drops tabs) for the hook's own layout.
clean() { printf '%s' "$1" | tr -d '\000-\037\177'; }
clean_lines() { printf '%s\n' "$1" | tr -d '\000-\011\013-\037\177'; }

# Legacy ##[command] text is parsed anywhere in a line, so the hook's output is relayed with
# workflow commands stopped, under a token a commit author cannot know ahead of time.
token() { od -An -tx1 -N16 /dev/urandom | tr -d ' \n'; }

checked=0
failed=0
msg="$(mktemp)"
trap 'rm -f "$msg"' EXIT

for sha in $merges; do
    checked=$((checked + 1))
    failed=$((failed + 1))
    echo "::error::$(git rev-parse --short "$sha") is a merge commit: $(clean "$(git log -1 --format=%s "$sha")"). Merge commits are not allowed here; rebase onto the base branch."
done

for sha in $shas; do
    checked=$((checked + 1))
    short="$(git rev-parse --short "$sha")"
    subject="$(git log -1 --format=%s "$sha")"
    git log -1 --format=%B "$sha" > "$msg"

    # The hook skips # lines as git comments, but a committed message never had comments stripped.
    first=""
    while IFS= read -r line || [ -n "$line" ]; do
        [ -n "${line//[[:space:]]/}" ] || continue
        first="$line"
        break
    done < "$msg"
    # The hook leaves a missing subject to git, which only aborts a local commit.
    if [ -z "$first" ]; then
        failed=$((failed + 1))
        echo "::error::$short has no subject"
        continue
    fi
    if [[ "$first" == '#'* ]]; then
        failed=$((failed + 1))
        echo "::error::$short starts with #, which git would have dropped as a comment: $(clean "$first")"
        continue
    fi

    if ! hook_err="$(bash "$hook" "$msg" 2>&1 >/dev/null)"; then
        stop_token="$(token)"
        echo "::stop-commands::$stop_token"
        clean_lines "$hook_err"
        echo "::$stop_token::"
        failed=$((failed + 1))
        echo "::error::$short does not follow the commit format: $(clean "$subject")"
    fi
done

echo "$checked commits checked, $failed failed"
[ "$failed" -eq 0 ]
