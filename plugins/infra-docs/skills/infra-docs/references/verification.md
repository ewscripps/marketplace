# Verification

Two passes: prove the facts before publishing, prove the pages after.

## Before publishing — accuracy

**Derive every fact from source code, never from existing prose.** This is the single
highest-value rule in the standard. On the AWS Org Networking estate, deriving from the
repo's own `docs/` would have published:

- Tier 1 CIDRs on an obsolete AZ stride (`x.0.0/.0.32/.0.64` instead of `x.0.0/x.4.0/x.8.0`)
- 8 interface VPC endpoints where there were 12
- Routing that predated the POC route table and every on-prem static route
- An account count of 31 where the map held 30

All four were in prose that looked authoritative and was internally consistent.

### Procedure

1. Parse the `.tf` files directly. For anything structural, brace-match rather than
   grepping line-wise — a naive `grep cidr_block` pulls NACL rules in with subnets.
2. Record the repo path and commit SHA for the provenance line.
3. **Spot-check at least five published values** back against the code before
   publishing, chosen across different pages and different resource types:

```bash
grep -A4 'resource "aws_subnet" "scrippsnet_prod_az1_use2"' subnets_workload_scrippsnet_prod.tf | grep cidr_block
grep 'amazon_side_asn' tgw.tf
grep -oE '[0-9]{12}' ram_scrippsnet_prod.tf | sort -u
grep -B2 -A3 'rule_no *= *500' subnets_workload_scrippsnet_prod.tf
```

4. **Report drift, do not silently fix or silently copy.** Where the repo's prose
   disagrees with its code, that is a finding for the user and a separate, reviewable
   change.
5. **Lint the prose.** `assets/ste_check.py` strips code, macros and tags from the
   storage-format HTML and runs the asd-ste100 linter over what is left. Fix every hard
   violation. Advisory findings (passive voice, compound tenses) are judgement calls.

```bash
python3 assets/ste_check.py page.html [page.html ...]
```

## After publishing — integrity

### Hierarchy

```bash
python3 assets/confluence.py tree --page <parent-id>
```

Confirm the index plus exactly the expected children, correctly nested, and that **every
returned title matches what was requested** — a silent " (2)" means a collision.

### Images

```bash
python3 assets/confluence.py verify --page <id>
```

Checks that each `ri:filename` in the body resolves to an attachment on **that same
page**, that the rendered view emits an `<img>`, and that the attachment downloads 200.

**Decode HTML entities before comparing filenames.** An em-dash stored in the body as
`&mdash;` will not string-match the attachment's literal `—`, producing a false BROKEN
report. This has already caused one wrong conclusion — three images reported broken that
were rendering perfectly.

A wrong page id yields a broken image that still returns HTTP 200 on the page fetch, so
checking the page loads is not sufficient.

### Repo side

```bash
tofu validate          # proves docs edits touched no HCL
git diff --stat        # confirm only intended files changed
python3 docs/diagrams/render.py && git diff --stat docs/diagrams/out/
```

## The read-through test

The one that actually matters. From the index page, can someone answer the two questions
this system gets asked most — without opening the repo?

For AWS Org Networking those are "I need a /23 for a new dev workload" and "prod ALB is
unreachable from a station, but only in us-west-2." If the answer is no, the gap belongs
on the runbook page or the troubleshooting page.

## Checklist

- [ ] Every fact derived from code, not prose
- [ ] Five or more values spot-checked against source
- [ ] Drift found in the repo's own docs reported to the user
- [ ] Prose passed the asd-ste100 pass and `ste_check.py` shows no hard violations
- [ ] Provenance line on every page, with the real commit SHA
- [ ] Titles match what was requested — no silent " (2)"
- [ ] Hierarchy is as intended
- [ ] Every image resolves, renders, and downloads 200
- [ ] No orphaned attachments left behind
- [ ] `render.py` legibility check passes — labels ≥7pt effective
- [ ] `tofu validate` passes; only intended files in `git diff`
- [ ] Read-through test passes for the two most common questions
