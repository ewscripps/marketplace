# Hierarchy and placement

Where a page goes, what the page set is, and what belongs on each one.

## Survey before you create anything

Never create a page from an assumption about the tree. Read it first.

```bash
# space id
getConfluenceSpaces(keys=["Infra"])        # -> id 3107422212, homepage 3107422470

# the tree
getConfluencePageDescendants(pageId=3107422470, depth=5, limit=250)
```

**The descendants endpoint paginates at 250 and returns a cursor in `_links.next`.**
The Infra space is well over 250 pages, so a single call silently gives you a partial
tree. Follow the cursor until it stops, then build the parent/child map from `parentId`.

Then read two or three sibling subtrees before writing. Convention here is carried by
example, not documented anywhere else.

## The Infra space taxonomy

Space key `Infra`, id `3107422212`, homepage `3107422470`.

| Branch | Page id | Holds |
|---|---|---|
| Standards & Policies | `3547103234` | Tagging, on-call rotation, review checklists |
| **Services** | `3547136001` | One child per platform or service — most infra docs |
| Disaster Recovery | `3547168769` | Per-system recovery plans |
| Data Centers | `3547037698` | FDC, HDC, physical site records |
| Projects | `3547201537` | Time-boxed efforts, by year |
| Compliance & Contracts | `3547234305` | SOX, SOWs — restricted |
| Ops | `3630694401` | Sam Foster's branch: AWS Infra > SSM |

Inside `Services`, two kinds of child coexist. Most are a flat bag of pages for a
technology (`DNS`, `Certificates`, `Storage`). The newer ones are **structured
per-system subtrees** — `Newsdesk` (`3822420003`), `Spelling Bee` (`3822485506`),
`AWS > AWS Org Networking` (`3822682181`). New work follows the structured pattern.

## Where does this page go?

| What you are documenting | Parent |
|---|---|
| A platform or service that is operated on an ongoing basis | `Services > <Name>` |
| A platform scoped to one cloud provider | `Services > AWS > <Name>` |
| How to recover a system after failure | `Disaster Recovery` |
| A policy, standard or convention the team must follow | `Standards & Policies` |
| A time-boxed effort with an end date | `Projects > <Year> Projects` |
| A physical site or rack | `Data Centers` |
| A third-party contract or audit artifact | `Compliance & Contracts` (restricted) |

If none fit, the answer is almost never a new top-level branch. Find the closest
existing parent and ask the user before adding a branch — the taxonomy's value is that
it is small.

## The canonical per-system subtree

```
<System Name>                          index
├── Architecture and <Domain> Map      topology, identifiers, allocations
├── Security Controls and <X>          controls, constraints, quotas
├── Making Changes                     runbook: onboarding, day-2, apply safety
├── Consumers and <Sharing>            who depends on this, who to call
└── Troubleshooting — <System>         symptom index, real postmortems
```

Six pages is the default, not a quota. **Minimum viable is three**: index,
architecture, troubleshooting. Add the others only when there is enough real content to
fill them — an empty "Consumers" page is worse than no page.

Drop any page you cannot tie to a question operators actually ask.

## What belongs on which page

| The question being asked | Page |
|---|---|
| What is this, and what does it own? | Index |
| What is `100.68.84.0/22`? Which account? Which region? | Architecture |
| What is the topology? How do the regions relate? | Architecture |
| Why is my traffic being dropped? What are the quotas? | Security Controls |
| How do I add a subnet / open a port / onboard a workload? | Making Changes |
| Is it safe to apply? What are the apply rules? | Making Changes |
| Who owns this account? Who do I call? | Consumers |
| It worked yesterday / it works one direction only | Troubleshooting |
| Deep per-resource reference | **Not Confluence — the repo** |

## The layering rule

Confluence is the distilled operator layer. The repo's `docs/` stays the deep reference,
next to the code it describes and inside the MR review that changes it.

- **Wiki**: what an operator needs to act, answerable in under a minute.
- **Repo**: exhaustive tables, design rationale, cost models, query cookbooks.
- **If it changes every sprint, it belongs in the repo.** Duplicating a
  code-coupled table onto the wiki guarantees the two drift apart.

The AWS Org Networking estate is the worked example: ~2,000 lines across 12 Markdown
files in `docs/`, distilled to six Confluence pages, with the wiki linking back rather
than copying.

## Naming

**Titles must be unique across the whole space, not just among siblings.** Confluence
does not reject a collision — it silently appends " (2)" and returns success. This has
already happened once: a second "Troubleshooting and Known Gotchas" became
"Troubleshooting and Known Gotchas (2)" because Spelling Bee already had that title.

Disambiguate with an em-dash suffix, matching sibling style:

```
Stacker — Architecture
Stacker — CI/CD & Deployment
Troubleshooting — Hub Networking
```

Check before creating:

```bash
searchConfluenceUsingCql(cql='space = "Infra" AND title ~ "<proposed title>"')
```

After creating, confirm the returned `title` matches what you asked for. If it came back
with a " (2)", rename it immediately — see `confluence.py` or the raw `PUT` in
[confluence-mechanics.md](confluence-mechanics.md).
