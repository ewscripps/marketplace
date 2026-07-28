<!-- expected-line: 8 -->
# Invalid: raw semicolon in a sequenceDiagram message after the ':'

The message text below is unquoted and contains a raw `;` instead of the `#59;` entity code.

```mermaid
sequenceDiagram
    Alice->>Bob: wait; then retry
```
