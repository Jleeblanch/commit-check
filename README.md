# commit-check

[![CI](https://github.com/Jleeblanch/commit-check/actions/workflows/ci.yml/badge.svg)](https://github.com/Jleeblanch/commit-check/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/Jleeblanch/commit-check)](LICENSE)
[![Release](https://img.shields.io/github/v/release/Jleeblanch/commit-check)](https://github.com/Jleeblanch/commit-check/releases)

A GitHub Action and a git hook that hold every commit subject in a pull request to one format: a type, an optional scope, then what changed. It fails the pull request on any commit that breaks the format and names each one.

## What it checks

Every commit a pull request adds:

- The subject format: one of six types (`feat`, `fix`, `refactor`, `test`, `docs`, `chore`), an optional scope in parentheses, a colon and a space, then the description.
- No review or fix-round narration in the subject, such as "fix round 2" or "final review".
- Merge commits are refused. Rebase onto the base branch instead.
- Git's own `Revert "..."` and `Reapply "..."` subjects pass, and `fixup!`, `squash!` and `amend!` prefixes pass when what follows conforms.

Commit text is printed safely: control characters are stripped, and the hook's output is relayed with workflow commands stopped, so a commit message cannot inject commands into your log.

## What it doesn't check

- Commit bodies. Whether a body says why needs judgment, so it stays with the author.
- Pushes made straight to a branch. The action reads a pull request's range.
- Commits outside the pull request's range.
- Local commits, unless you install the hook. From a clone of your repository:

```sh
curl -fsSL https://raw.githubusercontent.com/Jleeblanch/commit-check/main/commit-msg -o .git/hooks/commit-msg
chmod +x .git/hooks/commit-msg
```

## The format

```
<type>: <what changed>
<type>(<scope>): <what changed>
```

For example:

```
fix: a redirect is a failed post
feat(auth): sign in with a passkey
```

Why: a subject names the change, so a log reads as a list of what happened. The body says why. A subject that narrates the review that prompted it ("address review comments", "fix round 3") tells a later reader nothing about the code.

## Usage

Add a job to your pull-request workflow. Pin the action by full commit SHA, with the tag in a comment. `fetch-depth: 0` is required, because the action reads the whole range and a shallow clone does not have it.

```yaml
commit-format:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@<sha> # v7.0.1
      with:
        fetch-depth: 0
    - uses: Jleeblanch/commit-check@<sha> # v1.0.0
```

Dependabot's `github-actions` ecosystem bumps the pinned SHA when a new release is out. Its own commit subjects need the format too, so give it a prefix in `.github/dependabot.yml`:

```yaml
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    commit-message:
      prefix: "chore"
      include: "scope"
```

## License

MIT. See [LICENSE](LICENSE).
