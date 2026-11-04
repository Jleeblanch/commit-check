# Changelog

## 1.0.0 - 2026-11-04

- The `commit-msg` hook: checks the subject format of a commit message.
- `check-range.sh`: runs the hook over every commit in a pull request's range and reports each failure as a workflow error.
- The composite GitHub Action that runs the range check on a pull request.
