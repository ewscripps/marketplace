# Upgrade path for installs already polluted by the CA-134 defect

**Status**: proposal. Becomes `EDMDS-19` in the v1.1.0 SRD rewrite. Not implemented.
**Raised**: 2026-09-08, after cleaning this host by hand exposed that the shipped fix does nothing
for an existing install.

## The problem in one paragraph

CA-134's fix stops EDM writing into a foreign plugin's data directory. It does nothing about the
directories it already polluted. Worse, the C-4 backward-compatibility clause that makes the fix
safe for legitimate installs is exactly what keeps a polluted directory claimed: the ownership test
accepts any directory carrying `run/` or `patterns/`, and a polluted foreign directory carries both.
So an upgraded user keeps writing to the wrong place indefinitely, silently, and 3.3.0 reports
nothing.

## Who is affected

Anyone who ran EDM 3.2.x or earlier by explicit path, or through a hook, in a session where another
plugin was active. That is the normal case, not an edge case -- `CLAUDE_PLUGIN_DATA` is set by the
host to whichever plugin is running, and EDM's own scripts are invoked by explicit path throughout
development and by four hook consumers at runtime.

Measured on this one host before cleanup: `patterns/` at 68K holding 144 harvested findings across
three audit types, `run/` holding **85** stale markers at 340K, plus a second leak path writing
under an `edm/` subdirectory. Two mechanisms, not one.

## Why the shipped test cannot tell the two cases apart

```
_edm_datadir_owned():
  not a directory        -> adoptable
  has .edm-owned         -> owned
  has run/ or patterns/  -> owned      <- C-4 clause; this is the one that misfires
  empty                  -> adoptable
  otherwise              -> foreign
```

The third clause asks "does it carry EDM's footprint?". Both a legitimate legacy install and a
polluted foreign directory answer yes.

## The discriminator the test is missing

A legitimate EDM data root contains **only** EDM's own names. Verified on this host after cleanup:
`~/.local/share/edm` contains exactly `.edm-owned` and `run/`. The polluted directory contained
those *alongside* `node_modules`, `package.json` and `package-lock.json`.

So the C-4 clause should accept the footprint only when the directory contains nothing that is not
EDM's:

| Directory contents | Verdict |
|---|---|
| Only EDM names (`.edm-owned`, `run`, `patterns`) | EDM's own -- adopt |
| EDM names PLUS anything else | polluted foreign -- refuse |
| Foreign content, no EDM names | foreign -- refuse (already correct today) |
| Empty, or absent | adoptable (already correct today) |

**Compatibility checked, not assumed.** `wave8-smoke.sh:10302-10308`'s C-4 fixture builds
`${dir}/patterns/code-audit.md` and nothing else, so it still adopts under the tightened rule and
the assertion that guards against "every existing install would lose its harvested library" still
passes. That fixture is the direct descendant of the 58-assertion regression D46 records, so it is
the right thing to check against.

## Tightening alone is not enough, and would repeat the original mistake

If the test simply starts refusing a polluted directory, an affected user's EDM silently resolves
to a fresh empty root and their harvested pattern library becomes invisible. That is the same
failure D46 describes -- "a user would find their harvested pattern library apparently empty
because EDM had quietly moved to a new root" -- reached by a different route. Refusing without
telling anyone converts a wrong-location bug into a data-loss-shaped bug.

So the upgrade path needs three parts, in this order.

### Part 1 -- detect and report, before changing any behaviour

A read-only check that names the condition. Natural home is `edm-state validate` as a new
informational anomaly, alongside `PERM_RULES_MISSING` and `TORN_TOKEN_LINES`, plus a line in
`edm-state session-start` so it is seen without being asked for.

What it must report: the polluted path, what EDM has in it, and the destination. What it must not
do: refuse, block, or delete anything. Per the plugin's own convention, a setup condition is
visible but never blocking.

### Part 2 -- migrate on request, never automatically

A subcommand -- `edm-state migrate-data-dir`, mirroring the existing `migrate-path` precedent for
initiative directories -- that moves `patterns/`, `run/` and any `edm/` subtree from the polluted
root to the correctly-resolved one, and removes the `.edm-owned` sentinel EDM wrote there.

Three constraints on it:

- **Never touch anything that is not EDM's.** The foreign plugin's own files are the reason the
  directory is foreign.
- **Refuse rather than merge on collision.** If the destination already holds a `patterns/` delta,
  stop and report both paths. Silently merging two harvested libraries is worse than doing nothing.
- **Opt-in only.** An automatic migration that moves 340K between plugin data directories on
  upgrade is exactly the kind of surprise this plugin's `ask`-rule convention exists to prevent.

### Part 3 -- only then tighten the ownership test

Once detection ships and migration exists, the C-4 clause adopts the contents-only rule above. A
user who has not migrated keeps working (the directory still carries EDM's footprint and, for them,
also foreign content -- so they get the report, not silent relocation).

Sequencing matters: tightening first strands data, and migrating first with no detection means
nobody knows to run it.

## What this does not cover

- **Users who never upgrade.** Nothing reaches them. The CHANGELOG entry is the only channel, and
  it should say plainly that 3.2.x wrote into other plugins' data directories and how to check.
- **A polluted directory whose foreign plugin has since been uninstalled.** It then contains only
  EDM names and reads as legitimate under the tightened rule. Acceptable: the data is EDM's, the
  location is odd but harmless, and no other plugin is affected.
- **The two leak paths themselves.** The direct-root writes and the `edm/`-subdirectory writes are
  both symptoms of the resolver, already in scope as CA-100/CA-103/CA-105 (`EDMDS-13`). This
  document is about installs already carrying the damage.

## Note for the v1.1.0 rewrite

This is a nineteenth requirement, not a variation on `EDMDS-13`. `EDMDS-13` decides where data
*should* live going forward; this decides what to do about where it already is. They share a
mechanism and have different acceptance criteria.

It also strengthens the audit's P1 against `AD4`: that finding said AD4 names only `patterns/` when
the clause is `run/` **or** `patterns/`. Cleaning this host proved the point concretely -- `run/`
held 85 files to `patterns/`'s 5, so the omitted half was the larger one.
