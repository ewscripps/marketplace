# Valid: a diagram-shaped block inside a non-Mermaid fence is ignored entirely

The fence below is tagged `text`, not `mermaid` -- its content is never inspected by the
Mermaid lint class, even though it contains a raw `;` inside what looks like a label.

```text
flowchart TD
    A[Wait; then retry] --> B[Done]
```
