# Refresh and materiality

Documentation should be re-checked periodically, but **most commits do not warrant a
documentation change**. This is the rule for telling the difference.

Only changes with material impact on **architecture, security or operations** trigger an
update. Everything else gets a provenance stamp and nothing more.

## The provenance anchor

Every published page carries, as its second line:

```
Verified as of 19 September 2026 against `scripps/stg-ops/iac/ews-services/org-networking` `main cbdc84f`
```

That SHA is the baseline. The refresh diffs `<sha>..origin/main` and classifies what it
finds. A page without this line cannot be incrementally refreshed — it needs a full
derivation first.

## Classify at resource level, not file level

Path alone cannot decide. `subnets_workload_*.tf` holds both `aws_subnet` blocks and an
inline `aws_network_acl`, which route to different pages. Parse the diff hunks.

| Rule | Trigger | Verdict |
|---|---|---|
| M1 | `aws_subnet` added/removed, or `cidr_block` value changed | MATERIAL |
| M2 | `aws_vpc_endpoint` added/removed, or `service_name` changed | MATERIAL |
| M3 | RAM share / principal / resource association added or removed; an account id added, removed **or renamed** in an accounts map; share scope changed | MATERIAL |
| M4 | `rule_no`, `action`, `cidr_block`, `from_port`/`to_port` changed inside `aws_network_acl` | MATERIAL |
| M5 | `aws_route` or `aws_ec2_transit_gateway_route` added/removed, `destination_cidr_block` changed, or any route-table association added/removed | MATERIAL |
| M6 | Transit gateway, NAT gateway, or Network Firewall policy / rule-group body changed | MATERIAL |
| M7 | New comment block of 5+ lines in a `.tf` containing a date **and** failure language (`Found by`, `blackhole`, `one-directional`, `timeout`, `rehearsal`) | MATERIAL → Troubleshooting only |
| N1 | Only `.terraform.lock.hcl`, `.opentofu-version`, `.gitignore`, `plans/`, `docs/`, `ci/`, `scripts/` | NOT |
| N2 | Comment, whitespace or formatting only — no attribute value changed | NOT |
| N3 | Terraform address rename with identical attribute values and no principal or CIDR change | NOT |
| N4 | `outputs.tf` / `shared_outputs.tf` change mirroring something already classified | NOT — no independent weight |
| E1 | A watched file, but a resource type not listed above (security groups, Route 53, IAM, DNS firewall, monitoring, logging) | ESCALATE — ask a human, default MATERIAL |

## Signals, ranked

**Trustworthy alone.** Resource add/remove of a watched type. A changed value on a
watched attribute (`cidr_block`, `destination_cidr_block`, `rule_no`, `service_name`,
account ids). A dated postmortem comment block.

**Needs corroboration.** Paths touched — use to prioritise which hunks to parse, never
to decide. Commit body prose — often excellent for *writing* the page edit, but not for
gating it.

**Never trust alone — commit type prefixes.** Verified against this estate:

| Commit | Prefix says | Actually |
|---|---|---|
| `9a4c87d feat: document vpc_id in shared_outputs comment block` | feature | comment-only → NOT |
| `b6d89a6 refactor: rename newsdesk_storage_prod to newsdesk_prod` | refactor | account rename → MATERIAL (M3) |
| `1fa7865 docs: drop stale 'Terraform' from the tofu init step` | docs | touches only `plans/` → NOT |
| `21b2471 fix: route on-prem CIDRs from usw2 networking RT via peering` | fix | 4 TGW routes + postmortem → MATERIAL (M5, M7) |
| `97dd940 docs: correct drifted CIDR, endpoint and routing tables` | docs | edits HCL and corrects published facts |

Use prefixes to sort the review queue. Never to decide.

More worked examples, MATERIAL: `0665dc1` (new NACL `rule_no = 402` → M4),
`8656a09` (bedrock-runtime endpoint → M2), `6fafed5` (share scope narrowed from
org-wide to an explicit account list → M3). NOT: `31049da`, `6e87f6f` (provider
hashes → N1), `2a80576` (SSM plumbing, no principal or CIDR delta → N4).

## Change class → page

| Class | Page(s) |
|---|---|
| M1 subnet or CIDR add / remove / resize | Architecture |
| M1 + M3 together (new `subnets_workload_X.tf` + `ram_X.tf`) | Architecture **and** Consumers |
| M2 VPC endpoint | Architecture; + Security if it removes a NAT path |
| M3 RAM / principal / scope only | Consumers |
| M4 NACL rule | Security; + Consumers if it names a partner account's tier |
| M5 route or association | Architecture; + Troubleshooting if it fixes a reachability break |
| M6 firewall policy or NAT topology | Security |
| M7 postmortem comment | Troubleshooting |
| Changed apply procedure, provider pin, import convention | Making Changes |
| Any page edited | Index last-reviewed date + provenance on every touched page |

## Workflow

1. **Read provenance** from each page in the set. Pages drift independently — take the
   oldest SHA as the run baseline, but judge each page against its own.
2. **Validate the SHA**: `git fetch --all --prune && git cat-file -e "<sha>^{commit}"` (quote it — `^` is
   cmd.exe's escape character, and unquoted it silently becomes an invalid object,
   which this workflow would misread as *unreachable* and downgrade to DEGRADED).
   Unreachable after a squash merge or force push → fall back to the provenance *date*
   (`git rev-list -1 --first-parent --before="<date> 23:59" origin/main`), mark the run
   **DEGRADED**, and re-derive the page's tables rather than applying deltas.
3. **No provenance line** → do not incrementally refresh. Full derivation from code,
   then add the line.
4. **Classify** `git log --first-parent --no-merges <baseline>..origin/main`, applying
   the rubric per commit via `git show -U0`. Emit a table: commit, verdict, rule, target
   pages. An ESCALATE row stops the run pending a human.
5. **Decide by derived artifact, not by diff.** Re-derive the affected table at baseline
   and at HEAD; publish only if the rendered rows differ. This is what kills rename and
   reformat noise, and it is the step most worth not skipping.
6. **Update** one Confluence version per page, with a change comment listing the commits.
7. **Stamp provenance** on every page in the set, including ones with no body change — a
   NOT-MATERIAL verdict is still a verification, and the date should say so.

## Cadence

**Split detection from publication.**

Detection is deterministic and safe to automate: run the rubric monthly (volume is
roughly 8 non-merge commits a month, so a monthly batch is about one human read) and
post the verdict table as a comment on the index page.

Publication should stay interactive. Confluence writes need the connector's OAuth
session, and rewriting prose about a live production network unattended is not worth the
risk.

A GitLab scheduled pipeline is the wrong mechanism here: this repo has no root
`.gitlab-ci.yml`, and `ci/ipam-drift.gitlab-ci.yml` has sat unwired with a "not yet
wired up" header for weeks. A second orphaned job is the predictable outcome.

## Failure modes

**False negatives.** Unwatched resource types — mitigated by E1 defaulting to MATERIAL.
Squash merges destroying M7 comment blocks inside the range — also grep the working tree
for dated comment blocks absent from the Troubleshooting page. Console drift never
entering git at all — the provenance line is honest about this: it claims verification
against a *commit*, not against reality. Pair with a periodic full re-derivation.

**False positives.** Comment-only churn typed `feat:` — killed by N2 plus step 5.
`outputs.tf` double-counting — N4. Version spam from provenance-only stamps — bounded by
the monthly cadence. The agent rewriting good prose because a number moved — mitigated
by editing **table cells** by default; narrative sections change only on M7 or explicit
instruction.
