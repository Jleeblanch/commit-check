#!/usr/bin/env bash
# Shared helpers for the commit-msg tests: each case writes a message to a temp file, runs the
# hook on it and checks the exit status and, for a refusal, a substring of stderr.

HOOK="${COMMIT_MSG_HOOK:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/commit-msg}"
CASES_RUN=0
CASES_FAILED=0
_TMP="$(mktemp -d)"
trap 'rm -rf "$_TMP"' EXIT

_run_hook() {
    printf '%s' "$1" > "$_TMP/msg"
    HOOK_STDERR="$(bash "$HOOK" "$_TMP/msg" 2>&1 >/dev/null)"
    HOOK_STATUS=$?
}

_report() {
    CASES_RUN=$((CASES_RUN + 1))
    if [ "$1" = ok ]; then
        echo "PASS $2"
    else
        CASES_FAILED=$((CASES_FAILED + 1))
        echo "FAIL $2: $3"
    fi
}

pass_case() {
    local name="$1"
    _run_hook "$2"
    if [ "$HOOK_STATUS" -eq 0 ]; then _report ok "$name"
    else _report bad "$name" "expected exit 0, got $HOOK_STATUS: $HOOK_STDERR"; fi
}

refuse_case() {
    local name="$1" expected="${3:-}"
    _run_hook "$2"
    if [ "$HOOK_STATUS" -ne 1 ]; then
        _report bad "$name" "expected exit 1, got $HOOK_STATUS"
    elif [ -n "$expected" ] && [[ "$HOOK_STDERR" != *"$expected"* ]]; then
        _report bad "$name" "stderr lacks '$expected': $HOOK_STDERR"
    else
        _report ok "$name"
    fi
}

summary() {
    echo "$CASES_RUN cases, $CASES_FAILED failed"
    [ "$CASES_FAILED" -eq 0 ]
}
