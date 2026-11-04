#!/usr/bin/env bash
# Cases for action.yml and the CI workflow, read as text with grep: the composite action must pass
# its inputs through env, and CI must pin third-party actions by full SHA.
# shellcheck disable=SC2016  # ${{ }} is literal text in the YAML being grepped
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$here/lib.sh"

root="${ACTION_ROOT:-$(cd "$here/.." && pwd)}"
action="$root/action.yml"
ci="$root/.github/workflows/ci.yml"

problems=""
note() { problems="$problems; $1"; }

# action_runs_the_range_script_through_env
if [ ! -f "$action" ]; then
    note "action.yml missing"
else
    grep -qE '^  using: ["'\'']?composite["'\'']?[[:space:]]*$' "$action" || note "runs.using is not composite"
    grep -qE '^name: commit-check[[:space:]]*$' "$action" || note "name is not commit-check"
    grep -qE '^description: .+' "$action" || note "no description"
    grep -qE '^  icon: ["'\'']?git-commit' "$action" || note "branding icon missing"
    grep -qE '^  color: ["'\'']?blue' "$action" || note "branding color missing"
    [ "$(grep -cE '^\s*(- )?run:' "$action")" -eq 1 ] || note "expected exactly one run: line"
    grep -qE '^\s*(- )?run: "\$GITHUB_ACTION_PATH/check-range\.sh"[[:space:]]*$' "$action" || note "run is not exactly \"\$GITHUB_ACTION_PATH/check-range.sh\""
    grep -qE '^\s*shell: bash' "$action" || note "shell is not bash"
    grep -E '^\s*(- )?run:' "$action" | grep -qF '${{' && note "a run: line contains \${{"
    grep -qE '^\s*BASE: \$\{\{ inputs\.base \}\}' "$action" || note "env BASE not from inputs.base"
    grep -qE '^\s*HEAD: \$\{\{ inputs\.head \}\}' "$action" || note "env HEAD not from inputs.head"
    grep -qE '^  base:' "$action" || note "input base missing"
    grep -qE '^  head:' "$action" || note "input head missing"
    grep -qF 'default: ${{ github.event.pull_request.base.sha }}' "$action" || note "base default wrong"
    grep -qF 'default: ${{ github.event.pull_request.head.sha }}' "$action" || note "head default wrong"
fi
if [ -z "$problems" ]; then _report ok action_runs_the_range_script_through_env
else _report bad action_runs_the_range_script_through_env "${problems#; }"; fi

# ci_pins_by_sha
problems=""
if [ ! -f "$ci" ]; then
    note "ci.yml missing"
else
    uses_lines="$(grep -E '^\s*(- )?uses:' "$ci" | grep -vE 'uses: \./')"
    [ -n "$uses_lines" ] || note "no third-party uses: found"
    while IFS= read -r l; do
        [ -n "$l" ] || continue
        [[ "$l" =~ uses:\ [^@[:space:]]+@[0-9a-f]{40}\ +\#\ v[0-9] ]] || note "not pinned by SHA with # v comment: $l"
    done <<<"$uses_lines"
    grep -qE '^permissions:' "$ci" || note "no top-level permissions"
    [ "$(grep -A1 -E '^permissions:' "$ci" | tail -1 | tr -d ' ')" = "contents:read" ] || note "permissions is not contents: read"
    [ "$(grep -cE '^\s+[a-z-]+: (write|read-all|write-all)' "$ci")" -eq 0 ] || note "a write permission appears"
fi
if [ -z "$problems" ]; then _report ok ci_pins_by_sha
else _report bad ci_pins_by_sha "${problems#; }"; fi

# commit_format_job_is_limited_to_pull_requests: the action fails by design outside a pull request,
# so the README's snippet and CI's own job must both carry the guard.
problems=""
readme="$root/README.md"
guard="if: github.event_name == 'pull_request'"
if [ ! -f "$readme" ]; then
    note "README.md missing"
else
    snippet="$(awk '/^```yaml/{b=""; on=1; next} /^```/{if(on&&b ~ /uses: Jleeblanch\/commit-check@/){print b}; on=0; next} on{b=b $0 "\n"}' "$readme")"
    [ -n "$snippet" ] || note "README usage snippet not found"
    grep -qF "$guard" <<<"$snippet" || note "README usage snippet lacks $guard"
    grep -qE '^on: pull_request' <<<"$snippet" || note "README usage snippet lacks on: pull_request"
fi
if [ -f "$ci" ]; then
    job="$(awk '/^  commit-format:/{on=1; print; next} on && /^  [a-z]/{on=0} on{print}' "$ci")"
    grep -qF "$guard" <<<"$job" || note "ci.yml commit-format job lacks $guard"
    grep -qE '^\s*- uses: \./[[:space:]]*$' <<<"$job" || note "ci.yml commit-format job lacks uses: ./"
fi
if [ -z "$problems" ]; then _report ok commit_format_job_is_limited_to_pull_requests
else _report bad commit_format_job_is_limited_to_pull_requests "${problems#; }"; fi

summary
