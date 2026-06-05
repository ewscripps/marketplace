# Known Import Issues & Fixes

A running log of errors encountered in Wave → JPD imports and how they were resolved.

---

## Error Pattern Guide

| Error Message | Likely Cause | Fix |
|---|---|---|
| `Specify a number for the custom field (below 100,000,000,000,000)` | A number or checkbox field is receiving non-numeric data | Check `Is this a Revenue Initiative?` (must be `0`/`1`), Net Recurring Benefits, Implementation costs |
| `You cannot specify 'None' as an option together with other options` | Empty trailing cells in a multi-select repeated column, OR a single-select field has a second repeated column that is blank | Ensure empty multi-select slots write as `''` not `'nan'`. For single-select fields, use only 1 column |
| `The value [null=X] can't be added to the Custom Field [Y]` | Value `X` doesn't exist in JPD field `Y` | Check allowed values in field-mappings.md; update JPD field options or fix source value |
| `Legal and regulatory can't exceed 255 characters` | Legal field has content longer than 255 chars | Merge into Description instead — this is the default behaviour in the transform script |
| `brackets mismatch` in field names / garbled header | Wrong file type uploaded — user uploaded `.xlsx` instead of `.csv` | Remind user to upload the `.csv` output, not the Excel source file |
| Issue type defaults to `Idea` instead of `Initiative`/`Milestone` | `Issue Type` column not present, or "Map field value" not checked for Idea Type | Ensure `Issue Type` column exists in CSV and check "Map field value" in importer |

---

## Resolved Issues Log

### Issue: `##` headers rendering as numbered list in JPD descriptions
**Symptom:** Description shows `1. a. Initiative Description` instead of a bold heading  
**Root cause:** In Jira wiki markup, `##` means a second-level numbered list item (`1. a.`), not a heading  
**Fix:** Always use `h2. Heading` format, never `## Heading`  
**Status:** Fixed in transform.py md_to_jira() converter

---

### Issue: `nan` strings in multi-select columns
**Symptom:** `You cannot specify 'None' as an option together with other options`  
**Root cause:** pandas NaN objects in empty multi-select slots were writing as `'nan'` string  
**Fix:** Explicit empty-string check before writing: `'' if s.iloc[idx] == '' else s.iloc[idx]`  
**Status:** Fixed in transform.py

---

### Issue: Float precision artifacts in numeric fields
**Symptom:** `1127.6000000000001` in Net Recurring Benefits  
**Root cause:** Excel stores floats with binary precision artifacts  
**Fix:** `round(float(val), 2)` before writing  
**Status:** Fixed in transform.py format_number()

---

### Issue: Accountable Workstream `None` error (17 rows)
**Symptom:** `You cannot specify 'None' as an option together with other options` on rows with 1 AW value  
**Root cause:** AW was being sent as 2 repeated columns; empty second column treated as `None` alongside real value. AW is a single-select field.  
**Fix:** Use single AW column only. Full value `Product, Software Development / Engineering, Cybersecurity, and Data & Analytics` is valid as one option in JPD  
**Status:** Fixed in transform.py

---

### Issue: Revenue Initiative field blocking every row
**Symptom:** `Specify a number for the custom field` on 100% of rows  
**Root cause:** `Is this a Revenue Initiative?` is a JPD boolean/checkbox field requiring `0`/`1`. CSV had `Yes`/`No` text values  
**Fix:** Convert `Yes` → `1`, `No` → `0` in transform  
**Status:** Fixed in transform.py

---

### Issue: Sequencing Prioritization field rejecting all values
**Symptom:** WARN `{null=Medium Priority} can't be added to Sequencing prioritization`  
**Root cause:** Field was originally a ranking/ordering field that was reconfigured as a select. The old field type rejected text values  
**Fix:** Field was deleted and recreated as a proper select in JPD. Values now pass through as-is  
**Status:** Resolved — JPD field was updated by admin

---

### Issue: `Media Operations` rejected in Functional Dependency
**Symptom:** WARN `{null=Media Operations} can't be added to Functional dependency`  
**Root cause:** JPD field had `Media Ops` (abbreviated) not `Media Operations`  
**Fix:** JPD field option was updated to `Media Operations` to match source data  
**Status:** Resolved — JPD field option was updated by admin

---

### Issue: Initiative link cannot be set via CSV import
**Symptom:** `Outward issue link (Initiative)` column not appearing in Map Fields step  
**Root cause:** Initiative connection field (`customfield_13065`) is a `jira.polaris:connection` type — JPD-specific, not a standard Jira issue link. Not settable via CSV importer  
**Fix:** Set the Initiative link manually after import, or via API (see KIWI API Integration Reference, Section 10.6)  
**Status:** Known limitation — no CSV workaround

---

### Issue: Milestone issue type defaulting to `Idea` on import
**Symptom:** Milestones import as `Idea` type instead of `Milestone`  
**Root cause:** `Issue Type` column maps to "Idea Type" in importer; "Map field value" must be checked for the mapping to apply  
**Fix:** In Map Fields step, check "Map field value" for `Issue Type` → Idea Type, then confirm "Milestone" → "Milestone" in Map Values step  
**Status:** Known importer behaviour — must be set manually each run
