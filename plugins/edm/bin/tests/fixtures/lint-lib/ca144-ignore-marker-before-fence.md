# CA-144 regression fixture

An edm-lint-ignore marker directly above a fence opener must not corrupt the fence
state machine: the fenced content below must still be suppressed, and ordinary prose after
the fence's own closing line must NOT be treated as still-ignored or still-fenced.

Prose before the marker.

<!-- edm-lint-ignore -->
```text
Co-Authored-By: Should Be Suppressed By The Fence <fixture-inside@example.com>
```

Prose after the fence close must trip the attribution class exactly like it would if the
fence above never existed:
Co-Authored-By: Should Be Reported <fixture-after@example.com>
