# Diagrams

Diagram-as-code, committed next to the code it describes, rendered to SVG, uploaded as a
page attachment.

## Does this diagram earn its place?

Most do not. **A table beats a diagram for anything enumerable** — CIDR allocations,
account maps, rule lists. A table sorts, copy-pastes, and cannot drift the way a
rendered picture can.

A diagram earns its place when the *shape* is the point: topology, a traffic path, a
sequence, an asymmetry between two things that should be symmetric. Two per system is
usually right; the AWS Org Networking estate has exactly two.

## Notation

**Graphviz DOT is the default.** Infrastructure diagrams trend toward nested containment
— region > VPC > AZ > subnet — and Graphviz clusters keep children inside their parent
box. Mermaid's flowchart engine is built for directed graphs rather than boxes-in-boxes
and drifts nodes outside their own subgraph past about two levels of nesting.

**Mermaid is permitted** for flat flows, pipelines and sequences where it reads well and
is faster to write. If you use it, say why in the source header.

**SVG output is required either way.** Confluence renders SVG natively, it stays crisp
at any zoom, and the label text stays selectable and searchable.

## Rendering

**Never screenshot an editor viewport.** Six diagrams were published as 1063x1289
screenshots of the Mermaid Live Editor — identical dimensions regardless of content, the
`+ / RESET / −` zoom widget baked into the corner, cropped at both edges, 60–80% empty
canvas, and placeholder `X.X.0.0/16` CIDRs still in the boxes. Render from source.

```bash
python3 render.py                             # all sources + legibility check
                                              # Windows: py -3 render.py
dot -Tsvg src/topology.dot -o out/topology.svg
mmdc -i src/flow.mmd -o out/flow.svg -b white # if Mermaid
```

### Aspect ratio is the whole ballgame

Confluence content is about **820px** wide. A diagram wider than roughly 1.6:1 gets
scaled down until its labels are unreadable — which is what "the diagrams are hard to
read" almost always means.

`render.py` reports this for every source, so normally you just read its output. It
renders to a temporary directory rather than `/tmp`, which does not exist on Windows.

**Effective label size is the binding measure; ratio only predicts it.** Target
**7pt or better**, and treat ratio over **2.0** as a separate warning. A wide diagram
with few short labels can still read fine — `01-platform-context` is 1.93:1 and
perfectly legible at 8.9pt. Tall is fine at any ratio: Confluence pages scroll, they
do not widen. If the labels are too small:

1. `rankdir=TB` instead of `LR` — usually the single biggest win.
2. Cut nodes the page's tables already cover.
3. Split into two diagrams, or drop it and use a table.

Worked example: the topology diagram went 3.12:1 / 4.2pt → 1.57:1 / 7.6pt by switching
to `TB` and removing endpoint nodes the Architecture page already tabulates. The egress
diagram went 3.60:1 / 5.6pt → 1.15:1 / 12.8pt the same way.

> The ratio figure alone can mislead. `mmdc --scale 2` doubles the rendered font, so a
> Mermaid PNG can look bad by this metric and read fine in practice. **Open the image
> and look** before concluding a diagram needs work.

## Source conventions

```
docs/diagrams/
├── src/*.dot          committed
├── out/*.svg          committed, uploaded to Confluence
├── render.py
└── README.md          which source maps to which page
```

Every source starts with a header naming the files it was derived from, so the next
person knows what to re-check:

```dot
// Multi-region hub topology — Scripps AWS org networking
// Source of truth: vpc.tf, tgw.tf, nat_gateway.tf, vpc_endpoints.tf, ram_*.tf
// Render: dot -Tsvg multi-region-topology.dot -o ../out/multi-region-topology.svg
```

Every value in a diagram is duplicated from code, which means **a diagram is a drift
surface**. Keep them few, keep them derived, re-render on change.

Use `assets/diagram-preamble.dot` for the shared palette and node defaults so diagrams
look like each other. It asks for `Arial,Helvetica,sans-serif` rather than `Helvetica`,
because Helvetica is absent on Windows and the substitution shifts every coordinate —
see [platforms.md](platforms.md).

## Graphviz gotchas

- **Graph-level `rank=same` pulls nodes out of clusters and crashes the layout** with
  `Assertion failed: (GD_rank(g)[r].n <= GD_rank(g)[r].an) … mincross.c`. Declare rank
  constraints inside the cluster, or not at all. With `rankdir=LR` a chain already
  sequences left-to-right and needs no rank hint.
- `constraint=false` on an edge that should connect two nodes without driving their
  rank — use it for peering links and return paths that otherwise distort the layout.
- `compound=true` is required before `lhead`/`ltail` cluster-edge clipping works.
- Cluster names must start with `cluster_` or they are not drawn as a box.

## Mermaid gotchas

- A `direction` inside a subgraph is **ignored if any edge crosses that subgraph's
  boundary**, silently producing very tall diagrams. Set direction at the top level.
- `sequenceDiagram` does not render correctly with mermaid-cli 11.15.0 — actors and
  notes draw, message arrows and labels are invisible. Use a flowchart.
- Subgraphs are placed in reverse declaration order; declare them backwards to read 1, 2, 3.
- Escape `{` and `}` in node labels as `&lcub;` / `&rcub;`.

## Publishing

See [confluence-mechanics.md](confluence-mechanics.md). Refreshing a diagram is
re-render plus re-upload with no body edit — but note that replacing an existing
attachment needs the `/data` endpoint, not a plain POST, which returns 400.
