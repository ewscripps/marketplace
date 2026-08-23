<!-- expected-line: 14 -->
# Invalid: raw semicolon inside a [...] label in an INDENTED mermaid fence

The node label below is nested under a numbered list step, so its fence markers are indented
(unlike every other file in this directory, whose fences start at column 0). CA-038: the fix
that taught fence RECOGNITION to de-indent before counting backticks must not also suppress
VIOLATION detection inside the fence it recognizes -- this fixture is the regression guard for
that specific interaction.

1. Nested example:

   ```mermaid
   flowchart TD
       A[Wait; then retry] --> B[Done]
   ```
