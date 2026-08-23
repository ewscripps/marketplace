# Valid: sequenceDiagram with clean messages

No message text contains a semicolon, so nothing after any `:` needs escaping.

```mermaid
sequenceDiagram
    Alice->>Bob: hello there, how are you
    Bob-->>Alice: doing fine, thanks for asking
    Alice->>Bob: great to hear
```
