# dev — verification harness

Not shipped behaviour; these files exist to keep the version and tag rules
honest.

## `verify_version_rules.py`

Extracts the canonical Python block from
`skills/generate-release-notes/workflow.md` by its
`# --- rn:version (canonical) ---` / `# --- end rn:version ---` markers and
`exec`s it, then asserts its behaviour against real tag fixtures. Testing the
extracted block rather than a copy means the harness cannot silently drift from
what ships.

Run it after any change to that block:

    python3 plugins/tablo-release-notes/dev/verify_version_rules.py

Exit 0 and `ALL CHECKS PASSED` is the only acceptable result.

## `fixtures/tags-*.txt`

`git tag --list` output captured from `tablo-android`, `tablo-apple`, and
`tablo-roku`. Committed so runs are deterministic and need no repo checkouts.
They cover the cases that make this logic non-trivial:

- `tablo-android` mixes a legacy unprefixed `v2.x` line with the current
  `fast/release/` line — 369 tags, only 55 of which are current. Selecting a
  legacy tag as a baseline would produce a range spanning two unrelated
  codebases.
- `fast/release/v2.1` has `beta.2`/`beta.3` with no `beta.1`, and `rc.1` then
  `rc.4`–`rc.7`, so "previous index" must mean "highest lower index".
- `tablo-apple` tags two platforms at one version (`_ios`, `_tvos`) and holds
  both a main-app line (non-namespaced, `-release` for GA) and a FAST line
  (`fast/release/`, `-final` for GA).
- `tablo-roku` has no namespaces at all — the simple case must keep working.
- Junk tags (`vizbee-staging-test`, `fast/release/v2.2-975f7f5663`,
  `fast/release/v1.8-alpha.3-bluetooth`) must be excluded from ordering rather
  than crash it.

Refresh with:

    git -C <repo> tag --list > plugins/tablo-release-notes/dev/fixtures/tags-<name>.txt

Adding tags should never break the assertions, which name specific tags rather
than relying on counts.

## Why this exists

Three defects in v1 were only visible against real data:

1. `git tag --sort=-version:refname` sorts `v2.2-beta.1` *above* `v2.2`, so the
   old baseline logic returned the repo's newest tag for every prerelease.
2. The legacy Android tag line was indistinguishable from the current one.
3. `fixVersion = "<version>"` could never match a real Jira fix-version name.

The first two are asserted here. The third needs live Jira and is covered by the
live run in the implementation plan.
