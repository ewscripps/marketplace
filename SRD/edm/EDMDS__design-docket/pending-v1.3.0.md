# Held findings for srd.md v1.3.0

Same holding rationale as `pending-v1.2.0.md`, and the same narrow window: three audit lanes are
reading `srd.md` v1.2.0 as this is written, and editing it under them would make their findings
unreproducible and drift the version they audited from the version on disk. These land with the
v1.2.0 audit's own findings.

`architecture.md` is NOT held -- no lane is reading it yet, so its corrections are applied directly.

## B1 (P2) -- EDMDS-14's Decision block miscounts the sharing scripts

The block says `bin/_edm-cli-lib.sh` is sourced "by `edm-state:65` and fourteen more `bin/`
scripts". The `edm-architect` agent re-derived it while correcting `architecture.md`: it is **11
other `bin/` scripts** (16 sourcing sites under `bin/` in total) plus **3 `evals/` drivers**.

The load-bearing half of the claim -- that **all four hook consumers** source it, at
`edm-gateguard:52`, `edm-hookify:104`, `edm-bash-gate:69`, `edm-stop-gate:65` -- is exact, and that
is what the decision rests on. The count is decoration and it is wrong.

**Fix**: drop the count rather than correct it. D15 says not to write today's number into a
document, and a count of sourcing sites is precisely the figure that goes stale the moment someone
adds a script. "and most other `bin/` scripts" carries the same weight and cannot drift.

Worth noting for its own sake: this is the third count this document has stated and got wrong --
"six requirements carry a Rejected block" (five), "fourteen lens prompts" against a glob matching
fifteen, and now this. Each was decoration on a sound argument. v1.2.0 already stopped counting
Rejected blocks for exactly this reason; the rule should generalise.

## B2 (P1) -- EDMDS-07 AC7's rationale is right for a reason the SRD does not state

`EDMDS-07 AC7` resolves D40's harder half by asserting an all-lenses-N/A round cannot exist, on the
grounds that `--na-lenses` members must be in `CONDITIONAL_LENS_IDS` and that set holds only `L13`
(`bin/edm-state:5020-5022`). That is correct, and the AC's reduction to "the die still fires" is
correct.

What the SRD does not say is **why that assertion carries so much weight**. The `round_type`
derivation at `bin/edm-state:5038-5042` is the union comparison **alone**; the
`CONDITIONAL_LENS_IDS` membership test is a hard `die` upstream, before any state write, and the
code comment at `:5029-5031` says so outright -- "lenses_na's membership in CONDITIONAL_LENS_IDS is
already enforced above (a die fires before this point on any violation), so the union comparison
alone is sufficient here."

So the second conjunct of the `full` rule is **unfalsifiable at the point of derivation rather than
absent**, and AC7's assertion on the `die` is the only thing holding it up. Found by the
`edm-architect` agent while adding the conjunct to a diagram edge, where drawing it as a conjunction
would have misdescribed the mechanism.

**Fix**: add that reasoning to `EDMDS-07 AC7`'s rationale. The AC is already right; it should say
why it is load-bearing rather than leaving a reader to think it is a formality.
