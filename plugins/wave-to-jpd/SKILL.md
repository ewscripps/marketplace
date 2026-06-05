---
name: wave-to-jpd
description: Transform E.W. Scripps Wave exports (Excel/CSV) into import-ready CSVs for Jira Product Discovery (JPD). Use this skill whenever a user uploads a Wave export file and wants to prepare it for JPD import, mentions transforming Wave data for Jira, asks about formatting initiatives or milestones for JPD, or needs to convert Wave xlsx/csv exports into the correct format for the KIWI project. Also use when the user asks about re-running the Wave import, creating a new import CSV, or updating existing JPD import files. Covers both Initiative and Milestone issue types.
---

# Wave → Jira Product Discovery (JPD) Transform Skill

Transforms E.W. Scripps Wave exports into import-ready CSVs for the KIWI JPD project. Handles Initiatives and Milestones as separate workflows.

## Step 1 — Identify the Issue Type

Inspect the uploaded file's columns to determine whether it's an **Initiative** or **Milestone** export:

- **Initiative**: contains `Description of Initiative – be specific...`, `Net recurring benefits`, `Accountable Workstream`
- **Milestone**: contains `Milestone completion date`, `Milestone owner`, `Description and purpose`, `Initiative information`

If both types are present (or unclear), ask the user.

---

## Step 2 — Run the Transform Script

Always run `scripts/transform.py` — do not rewrite the transformation logic inline.

```bash
python3 scripts/transform.py \
  --input "/path/to/uploaded/file.xlsx" \
  --type initiative \          # or: milestone
  --output "/mnt/user-data/outputs/import_ready.csv"
```

For milestones: if the file contains multiple initiatives (check `Initiative information` column for distinct values), split into one CSV per initiative automatically using `--split`.

```bash
python3 scripts/transform.py \
  --input "/path/to/file.xlsx" \
  --type milestone \
  --split \
  --output "/mnt/user-data/outputs/"
```

---

## Step 3 — Verify Output

After the script runs, confirm:

- [ ] Row count matches source (minus any intentionally dropped rows)
- [ ] No `nan` strings in multi-select columns
- [ ] `Issue Type` column present with correct value on every row
- [ ] Date columns formatted as `yyyy-mm-dd`
- [ ] Revenue Initiative is `0`/`1`, not `Yes`/`No`
- [ ] `JPD Description` starts with `h2. ` headers, not `##`

Report any rows that couldn't be transformed cleanly.

---

## Step 4 — Deliver Files

Present the output CSV(s) to the user and remind them of the **Map Fields** settings:

### Initiative imports — check "Map field value" for:
- `Accountable Workstream`
- `Cross-functional support needed`
- `Functional dependency`
- `Initial Tech Sequencing prioritization`

### Milestone imports — check "Map field value" for:
- `Issue Type` (Idea Type)
- `Milestone Type`
- `Planning summary`
- `Cross-functional support needed`

### Never check "Map field value" for:
- `JPD Description` / Description
- Any date field
- Any number field (Wave ID, Net Recurring Benefits, Implementation costs)
- `Initiative Owner` / `Milestone Owner`

### Always set to "Don't map this field":
- `Status` — set via Jira workflow, not on import
- Any of the 3 source columns that were merged into description:
  - `Functional requirements needed for the Initiative`
  - `Tech Sequencing notes`
  - `Regulatory rules or laws that must be fulfilled by Tech work`

---

## Reference Files

- `references/field-mappings.md` — complete field ID, Wave column, and transformation reference for both issue types
- `references/known-issues.md` — historical import errors and their fixes
- `scripts/transform.py` — the canonical transformation script

---

## When the User Asks About Changes

If the user reports a validation error or wants to adjust a mapping:

1. Check `references/known-issues.md` first — this error may have been seen before
2. If it's a new issue, diagnose from the log (see known-issues.md for error pattern guide)
3. Fix the script if the issue is systematic; fix the CSV directly if it's a one-off
4. Re-run the script and re-verify
