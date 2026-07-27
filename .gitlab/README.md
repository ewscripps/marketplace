# .gitlab/

CI-adjacent metadata that is not itself pipeline configuration (that lives in `.gitlab-ci.yml`
at the repository root).

## `edm-validate-baseline.txt`

The known-good warning count from `claude plugin validate plugins/edm/` at the time the CI
pipeline was added (EDMV3-T21). The `validate:plugin-cli` job (tier 2 of the two-tier validate
stage) compares the current warning count against this file and fails the job -- non-blocking,
`allow_failure: true` -- if a new warning was introduced.

Current value: `1`, corresponding to the one known warning ("CLAUDE.md at the plugin root is
not loaded as project context") that `claude plugin validate` reports for `plugins/edm/` today.
This is an accepted, informational finding, not a defect this ticket fixes.

Update this file only when a warning is deliberately accepted (bump the count and note why in
the MR description) or removed (lower the count in the same MR that removes it). Do not bump it
to silence an unreviewed new warning.
