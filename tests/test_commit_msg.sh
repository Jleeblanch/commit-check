#!/usr/bin/env bash
# Cases for the commit-msg hook.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$here/lib.sh"

SCISSORS='# ------------------------ >8 ------------------------'
README='https://github.com/Jleeblanch/commit-check#readme'

pass_case six_types_feat $'feat: close-out reads the archive\'s alerts\n'
pass_case six_types_fix $'fix: a redirect is a failed post\n'
pass_case six_types_refactor $'refactor: one helper for the webhook settings\n'
pass_case six_types_test $'test: pin the shrink alert\n'
pass_case six_types_docs $'docs: today\'s daily note\n'
pass_case six_types_chore $'chore: regenerate the indexes\n'
pass_case a_scope_passes $'fix(recall): cap the judge\'s picks by its own order\n'

while IFS= read -r s; do
    refuse_case "no_listed_type: $s" "$s"$'\n\nA body.\n' "Subject: $s"
done <<'LIST'
Close the audit's riders and dead code
perf: close-out runs due harnesses three at a time
build(deps): bump boto3
Fix: a capitalized type
fix:no space after the colon
fix:
fix(): an empty scope
fix
Hotfix: a typo in the README
Revert the parser change
LIST
refuse_case no_listed_type_trailing_space_subject $'fix: \n\nA body.\n' 'BLOCKED'

refuse_case body_does_not_rescue $'Plain sentence\n\nfix: written in the body\n'
pass_case comment_and_blank_lines_skipped $'\n# Please enter the commit message\n#\n\ndocs: the subject after the comments\n'
refuse_case no_final_newline_still_checked 'Plain via editor'
refuse_case blank_first_line_does_not_hide $'\n\nPlain sentence subject\n'
refuse_case commented_good_subject_does_not_hide_bad $'# docs: a commented line\nPlain sentence subject\n'
pass_case no_subject_left_to_git $'# only comments\n\n'

pass_case revert_passes $'Revert "fix: a redirect is a failed post"\n\nThis reverts commit 0123abc.\n'
pass_case revert_nonconforming_passes $'Revert "Close the audit\'s riders"\n\nThis reverts commit 0123abc.\n'
pass_case reapply_passes $'Reapply "fix: a redirect is a failed post"\n\nThis reverts commit 0123abc.\n'

pass_case prefix_fixup $'fixup! fix: a redirect is a failed post\n'
pass_case prefix_squash $'squash! docs: today\'s daily note\n'
pass_case prefix_amend $'amend! feat: close-out reads the archive\'s alerts\n'
pass_case prefix_fixup_twice $'fixup! fixup! test: pin the shrink alert\n'
refuse_case prefix_does_not_excuse_rest $'fixup! Plain sentence subject\n'

refuse_case narration_review_round "fix: review round 1 fixes"$'\n' 'Subject: fix: review round 1 fixes'
refuse_case narration_fix_round $'fix: Task 4 fix round 2: pin the parser\n' 'Subject: fix: Task 4 fix round 2: pin the parser'
refuse_case narration_changelog_round $'test: changelog for round 1\n' 'Subject: test: changelog for round 1'
refuse_case narration_hyphen_round $'docs: round-4 Minors recorded\n' 'Subject: docs: round-4 Minors recorded'
refuse_case narration_final_review $'docs: final review fixes\n' 'Subject: docs: final review fixes'
refuse_case narration_capitalized $'fix: Review Round fixes\n' 'Subject: fix: Review Round fixes'

pass_case ordinary_round_the_price $'fix: round the price to two decimals\n'
pass_case ordinary_around_3 $'fix: retry around 3 times\n'
pass_case ordinary_reviewer $'docs: what the reviewer checks\n'
pass_case review_round_in_body_allowed $'fix: pin the parser\n\nFound in review round 2.\n'

pass_case scissors_ends_the_message $'\n# Please enter...\n'"$SCISSORS"$'\ndiff --git a/x b/x\n'
refuse_case scissors_after_a_bad_subject_still_refuses $'Plain sentence\n'"$SCISSORS"$'\nfix: x\n'
pass_case fixup_revert_passes $'fixup! Revert "fix: a redirect is a failed post"\n'
refuse_case problem_names_the_type_reason $'Plain sentence\n' 'Problem: it does not start with one of the types'
refuse_case problem_names_the_round_reason $'fix: review round 1 fixes\n' 'Problem: it names a review or fix round'
refuse_case prefix_needs_its_space $'fixup!word feat: the rest\n'
pass_case crlf_subject_passes $'fix: a windows line\r\n'
refuse_case crlf_bad_subject_refused $'Plain sentence\r\n'

marker="/tmp/commit-check-meta-$$"
rm -f "$marker"
# shellcheck disable=SC2016
pass_case metacharacters_are_text 'fix: handle `touch '"$marker"'` and $(touch '"$marker"') in names'$'\n'
refuse_case metacharacters_are_text_refused 'Plain `touch '"$marker"'`'$'\n'
if [ -e "$marker" ]; then _report bad metacharacters_create_no_file "file created"; rm -f "$marker"
else _report ok metacharacters_create_no_file; fi

refuse_case stderr_points_at_the_readme $'Plain sentence\n' "$README"

summary
