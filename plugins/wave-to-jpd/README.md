# wave-to-jpd

**Transform E.W. Scripps Wave exports into import-ready CSVs for Jira Product Discovery (KIWI project).**

---

## What It Does

Takes a Wave Excel or CSV export and produces a clean, validated CSV ready for Jira's bulk import tool — with all field type conversions, value mappings, and multi-select formatting handled automatically.

Supports two issue types:
- **Initiatives** — from the standard Wave initiative export
- **Milestones** — from Wave milestone exports, with optional splitting by initiative

---

## When to Use It

Trigger this skill any time you're:
- Preparing a Wave export for import into the KIWI JPD project
- Re-running a Wave import after data has been updated
- Converting a new batch of initiatives or milestones from Wave
- Troubleshooting a JPD import validation error

---

## Prerequisites

- Python 3 with `pandas` and `openpyxl` installed
- A Wave export file (`.xlsx` or `.csv`)
- Access to the KIWI Jira Product Discovery project

---

## Usage

### Initiatives

```bash
python3 scripts/transform.py \
  --input path/to/wave_export.xlsx \
  --type initiative \
  --output path/to/output.csv
```

### Milestones (single initiative)

```bash
python3 scripts/transform.py \
  --input path/to/milestones.xlsx \
  --type milestone \
  --output path/to/output.csv
```

### Milestones (multiple initiatives — auto-split)

```bash
python3 scripts/transform.py \
  --input path/to/milestones.xlsx \
  --type milestone \
  --split \
  --output path/to/output/directory/
```

Produces one CSV per initiative, named by initiative slug.

---

## What Gets Transformed

### Both Issue Types

| Transformation | Detail |
|---|---|
| Description merge | Multiple Wave text columns combined into one JPD Description field with `h2.` section headers |
| Markdown → Jira wiki markup | `**bold**` → `*bold*`, `## Heading` → `h2. Heading`, numbered lists, tables |
| Date formatting | All dates output as `yyyy-mm-dd` |
| Issue Type | `Issue Type` column injected on every row (`Initiative` or `Milestone`) |

### Initiatives Only

| Transformation | Detail |
|---|---|
| Revenue Initiative | `Yes` → `1`, `No` → `0` (JPD checkbox field) |
| Float precision | Net Recurring Benefits and Implementation Costs rounded to 2dp |
| Multi-select explosion | Semicolon-delimited fields split into repeated columns for Jira importer |
| Accountable Workstream | Capitalisation fix (`Procured spend` → `Procured Spend`) |

### Milestones Only

| Transformation | Detail |
|---|---|
| Cross-functional support | Person names stripped: `Marketing (Desere Wolfe)` → `Marketing` |
| Initiative split | File split into one CSV per initiative when multiple are present |

---

## Jira Importer — Map Fields Settings

After generating the CSV, use these settings in Jira's bulk import tool.

### Check "Map field value" for:

**Initiatives:** `Accountable Workstream`, `Cross-functional support needed`, `Functional dependency`, `Initial Tech Sequencing prioritization`

**Milestones:** `Issue Type` (Idea Type), `Milestone Type`, `Planning summary`, `Cross-functional support needed`

### Never check "Map field value" for:
Description, date fields, number fields, Owner fields

### Always set to "Don't map this field":
`Status` (controlled by Jira workflow), and the three source columns merged into Description

---

## Known Limitations

| Limitation | Workaround |
|---|---|
| Initiative link on Milestones can't be set via CSV | Set manually in JPD after import, or via API (`customfield_13065`) |
| Milestone issue type may default to "Idea" | Check "Map field value" for Issue Type → Idea Type in importer |
| Status can't be imported | Leave unmapped; use workflow transitions |

---

## File Structure

```
wave-to-jpd/
├── SKILL.md                        # Claude skill instructions
├── scripts/
│   └── transform.py                # Core transformation script
└── references/
    ├── field-mappings.md           # Wave column → JPD field reference
    └── known-issues.md             # Error log and fixes
```

---

## Project Context

Built for E.W. Scripps' **KIWI** Jira Product Discovery project (`ewscripps.atlassian.net`). Field IDs, allowed values, and transformation rules are specific to this project. See `references/field-mappings.md` for the full field-by-field reference.

Related documentation in Confluence (STGP space):
- *Wave → JPD Import: Transformation Process & Skill* — process overview and historical import notes
- *KIWI API Integration Reference* — for API-based creation (bypasses the importer entirely)
- *KIWI Field Reference* — complete field list with types and allowed values
