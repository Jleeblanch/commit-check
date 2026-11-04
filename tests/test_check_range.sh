#!/usr/bin/env bash
# Cases for check-range.sh: each builds a scratch repo, runs the script in it with BASE and HEAD
# set, and checks the exit status and the output. Fixture repos use throwaway config and
# --no-verify; they are not the real repo's hooks.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$here/lib.sh"

SCRIPT="${CHECK_RANGE:-$(cd "$here/.." && pwd)/check-range.sh}"
_N=0

# new_repo: creates a scratch repo with a first commit and cd's into it; sets REPO.
new_repo() {
    _N=$((_N + 1))
    REPO="$_TMP/repo$_N"
    git init -q -b main "$REPO"
    cd "$REPO" || exit 1
    git config user.name t
    git config user.email t@example.com
    git config commit.gpgsign false
    git config core.hooksPath /dev/null
    commit 'chore: base'
}

# commit <subject>: an empty commit with that subject.
commit() { git commit -q --allow-empty --no-verify -m "$1"; }

# run_range <name> <want_status|nonzero> <substring>...: runs the script with BASE and HEAD from the
# environment, then checks status and that the combined output holds every substring.
run_range() {
    local name="$1" want="$2" out status s
    shift 2
    out="$(bash "$SCRIPT" 2>&1)"
    status=$?
    RANGE_OUT="$out"
    if { [ "$want" = nonzero ] && [ "$status" -eq 0 ]; } || { [ "$want" != nonzero ] && [ "$status" -ne "$want" ]; }; then
        _report bad "$name" "expected exit $want, got $status: $out"
        return
    fi
    for s in "$@"; do
        if [[ "$out" != *"$s"* ]]; then
            _report bad "$name" "output lacks '$s': $out"
            return
        fi
    done
    _report ok "$name"
}

# --- clean_range_passes
new_repo
export BASE HEAD
BASE="$(git rev-parse HEAD)"
commit 'feat: one'
commit 'fix: two'
HEAD="$(git rev-parse HEAD)"
run_range clean_range_passes 0 '2 commits checked, 0 failed'

# --- bad_subject_fails_and_names_it
new_repo
BASE="$(git rev-parse HEAD)"
commit 'feat: fine'
commit 'Plain sentence'
bad="$(git rev-parse --short HEAD)"
HEAD="$(git rev-parse HEAD)"
run_range bad_subject_fails_and_names_it 1 '::error::' "$bad" 'Plain sentence' '2 commits checked, 1 failed'

# --- every_bad_commit_is_reported
new_repo
BASE="$(git rev-parse HEAD)"
commit 'Bad one'
commit 'Bad two'
commit 'Bad three'
HEAD="$(git rev-parse HEAD)"
run_range every_bad_commit_is_reported 1 '3 commits checked, 3 failed'
n="$(grep -c '::error::' <<<"$RANGE_OUT")"
if [ "$n" -eq 3 ]; then _report ok every_bad_commit_has_an_error_line
else _report bad every_bad_commit_has_an_error_line "expected 3 ::error:: lines, got $n"; fi

# --- merge_commit_fails
new_repo
BASE="$(git rev-parse HEAD)"
git checkout -q -b side
commit 'feat: on the side'
git checkout -q main
commit 'feat: on main'
git merge -q --no-ff --no-verify -m 'feat: merge side' side
HEAD="$(git rev-parse HEAD)"
run_range merge_commit_fails 1 '::error::' 'merge commit' 'rebase'

# --- hash_subject_fails
new_repo
BASE="$(git rev-parse HEAD)"
git commit -q --allow-empty --no-verify --cleanup=verbatim -m '# fix: hidden'
HEAD="$(git rev-parse HEAD)"
run_range hash_subject_fails 1 '::error::' 'starts with #'

# --- empty_base_fails
new_repo
HEAD="$(git rev-parse HEAD)"
BASE=""
run_range empty_base_fails 1 '::error::' 'no commit range' 'pull_request'

# --- shallow_clone_fails
new_repo
first="$(git rev-parse HEAD)"
commit 'feat: two'
commit 'feat: three'
shallow="$_TMP/shallow$_N"
git clone -q --depth 1 "file://$REPO" "$shallow"
cd "$shallow" || exit 1
BASE="$first"
HEAD="$(git rev-parse HEAD)"
run_range shallow_clone_fails 1 '::error::' 'fetch-depth: 0'

# --- deeper_shallow_clone_fails: depth 2 holds BASE and HEAD but the range's middle is partial
new_repo
BASE="$(git rev-parse HEAD)"
commit 'Bad one'
commit 'Bad two'
commit 'feat: three'
HEAD="$(git rev-parse HEAD)"
shallow="$_TMP/shallow$_N"
git clone -q --depth 2 "file://$REPO" "$shallow"
cd "$shallow" || exit 1
git fetch -q --depth 2 origin "$BASE"
run_range deeper_shallow_clone_fails 1 '::error::' 'fetch-depth: 0'

# --- empty_message_fails
new_repo
BASE="$(git rev-parse HEAD)"
git commit -q --allow-empty --allow-empty-message --no-verify -m ''
short="$(git rev-parse --short HEAD)"
HEAD="$(git rev-parse HEAD)"
run_range empty_message_fails 1 "::error::$short has no subject"

# --- whitespace_message_fails
new_repo
BASE="$(git rev-parse HEAD)"
git commit -q --allow-empty --allow-empty-message --no-verify --cleanup=verbatim -m "$(printf '   \n\n  \n')"
short="$(git rev-parse --short HEAD)"
HEAD="$(git rev-parse HEAD)"
run_range whitespace_message_fails 1 "::error::$short has no subject"

# --- unreadable_range_fails: both ends exist, a commit between them is gone
new_repo
BASE="$(git rev-parse HEAD)"
commit 'feat: middle'
mid="$(git rev-parse HEAD)"
commit 'feat: tip'
HEAD="$(git rev-parse HEAD)"
rm -f ".git/objects/${mid:0:2}/${mid:2}"
run_range unreadable_range_fails nonzero

# --- empty_range_passes
new_repo
BASE="$(git rev-parse HEAD)"
HEAD="$BASE"
run_range empty_range_passes 0 '0 commits checked, 0 failed'

# --- metacharacter_subject_is_data
new_repo
BASE="$(git rev-parse HEAD)"
marker="$_TMP/pwned"
commit "Plain \`touch $marker\`"
HEAD="$(git rev-parse HEAD)"
run_range metacharacter_subject_is_data 1 '1 commits checked, 1 failed'
if [ -e "$marker" ]; then _report bad metacharacter_marker_not_created "marker file exists"
else _report ok metacharacter_marker_not_created; fi

# no_injection <name>: RANGE_OUT must hold no raw control byte and no line that is a workflow command
# other than the script's own ::error::.
no_injection() {
    if [[ "$RANGE_OUT" == *$'\r'* ]] || grep -q '^::warning::' <<<"$RANGE_OUT"; then
        _report bad "$1" "output carries a raw CR or a ::warning:: line: $(printf %q "$RANGE_OUT")"
    else _report ok "$1"; fi
}

# --- control_characters_in_subject_are_stripped
new_repo
BASE="$(git rev-parse HEAD)"
commit $'Plain\r::warning::injected\x1b[31m'
HEAD="$(git rev-parse HEAD)"
run_range control_characters_in_subject_fail 1 '1 commits checked, 1 failed'
no_injection control_characters_in_subject_are_stripped

# --- control_characters_in_merge_subject_are_stripped
new_repo
BASE="$(git rev-parse HEAD)"
git checkout -q -b side
commit 'feat: on the side'
git checkout -q main
commit 'feat: on main'
git merge -q --no-ff --no-verify -m $'feat: merge\r::warning::injected' side
HEAD="$(git rev-parse HEAD)"
run_range control_characters_in_merge_subject_fail 1 'merge commit'
no_injection control_characters_in_merge_subject_are_stripped

# --- control_characters_after_hash_are_stripped
new_repo
BASE="$(git rev-parse HEAD)"
git commit -q --allow-empty --no-verify --cleanup=verbatim -m $'# fix\r::warning::injected'
HEAD="$(git rev-parse HEAD)"
run_range control_characters_after_hash_fail 1 'starts with #'
no_injection control_characters_after_hash_are_stripped

# --- legacy_commands_in_relayed_hook_output_are_stopped
new_repo
BASE="$(git rev-parse HEAD)"
commit 'Plain ##[warning]injected'
HEAD="$(git rev-parse HEAD)"
run_range legacy_command_subject_fails 1 '1 commits checked, 1 failed'
first_out="$RANGE_OUT"
run_range legacy_command_subject_fails_again 1 '1 commits checked, 1 failed'
second_out="$RANGE_OUT"

# stopped_ok <output>: every ##[ line outside our own ::error:: lines sits between a
# ::stop-commands::T line and its matching ::T:: line; prints the token.
stopped_ok() {
    awk '
        /^::stop-commands::/ { if (tok != "") bad = 1; tok = substr($0, 18); n++; next }
        tok != "" && $0 == "::" tok "::" { tok = ""; next }
        /##\[/ && $0 !~ /^::error::/ && tok == "" { bad = 1 }
        END { exit (bad || tok != "" || n == 0) }
    ' <<<"$1"
}
token_of() { grep -m1 '^::stop-commands::' <<<"$1" | cut -c18-; }

if stopped_ok "$first_out"; then _report ok legacy_commands_are_inside_a_stopped_block
else _report bad legacy_commands_are_inside_a_stopped_block "$(printf %q "$first_out")"; fi
t1="$(token_of "$first_out")"; t2="$(token_of "$second_out")"
if [ -n "$t1" ] && [ "$t1" != "$t2" ]; then _report ok stop_commands_token_differs_per_run
else _report bad stop_commands_token_differs_per_run "tokens: '$t1' '$t2'"; fi

cd "$here" || exit 1
summary
