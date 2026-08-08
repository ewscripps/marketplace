# Valid: an indented non-Mermaid fence inside a numbered step still suppresses other classes

This proves the linter de-indents fence markers before classifying them.

1. Nested example:

   ```text
   Co-Authored-By: Example Person <example@example.com>
   An em dash inside an indented fence — like this one — is class-2 (unicode) suppressed too.
   ```
