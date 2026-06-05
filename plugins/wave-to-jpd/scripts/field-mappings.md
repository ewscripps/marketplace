# Wave → JPD Field Mappings Reference

Complete mapping of Wave source columns to JPD fields for both issue types.

---

## Initiative Mappings

| JPD Field | Field ID | Wave Source Column | Transformation |
|---|---|---|---|
| Summary | `summary` | `Name` | Pass as-is |
| Description | `description` | **4 columns merged** | See description template below |
| Issue Type | hardcoded | — | Always `Initiative` |
| Wave ID | `customfield_12558` | `#` | Pass as integer |
| Net Recurring Benefits | `customfield_12559` | `Net recurring benefits (latest estimate, annualized)` | `round(float, 2)` — fixes Excel precision |
| Implementation costs | `customfield_13060` | `(LW) Implementation costs (latest estimate, annualized)` | `round(float, 2)` |
| Accountable Workstream | `customfield_12560` | `Accountable Workstream` | Fix cap: `Procured spend` → `Procured Spend`. Full combined value is valid single option |
| Initiative Owner | `customfield_12561` | `Initiative Owner` | Plain text |
| Functional dependency | `customfield_12564` | `Functional dependency` | Split on `; ` → repeated columns (CSV) or array (API) |
| Tech Sequencing approach | `customfield_12565` | `Tech Sequencing approach` | Pass as-is |
| Is this a Revenue Initiative? | `customfield_12568` | `Is this a Revenue Initiative?` | `Yes` → `1`, `No` → `0` |
| Cross-functional support needed | `customfield_12569` | `Cross-functional support needed` | Split on `; ` → repeated columns (CSV) or array (API) |
| L4 Date | `customfield_12570` | `(LW) L4 latest estimated date` | `yyyy-mm-dd` |
| Sequencing prioritization | `customfield_12603` | `Initial Tech Sequencing prioritization` | Pass as-is — values match JPD options exactly |
| Item Source | `customfield_12637` | — | Hardcode to `Wave` for all API-created items |

### Columns intentionally NOT mapped (merged into description instead)

| Wave Column | Reason |
|---|---|
| `Description of Initiative – be specific, what are we actually changing that creates value` | Merged into Description as `h2. Initiative Description` |
| `Functional requirements needed for the Initiative` | Merged into Description as `h2. Functional Requirements` |
| `Tech Sequencing notes` | Merged into Description as `h2. Tech Sequencing Notes` |
| `Regulatory rules or laws that must be fulfilled by Tech work` | Merged into Description as `h2. Legal & Regulatory Requirements` (255-char limit on standalone field makes it unusable) |
| `Access` | Internal Wave field, not relevant in JPD |
| `Stage (simplified)` | Internal Wave field, not relevant in JPD |
| `Initiative information` | Reference only — not a JPD field |

### Description Template

```
h2. Initiative Description
{Description of Initiative...}

h2. Functional Requirements
{Functional requirements needed for the Initiative}

h2. Tech Sequencing Notes
{Tech Sequencing notes}

h2. Legal & Regulatory Requirements
{Regulatory rules or laws that must be fulfilled by Tech work}
```

---

## Milestone Mappings

| JPD Field | Field ID | Wave Source Column | Transformation |
|---|---|---|---|
| Summary | `summary` | `Name` | Pass as-is |
| Description | `description` | `Description and purpose` | Wrap in `h2. Description and Purpose` header |
| Issue Type | hardcoded | — | Always `Milestone` |
| Milestone ID | `customfield_13061` | `#` | Pass as integer |
| Milestone Owner | `customfield_13055` | `Milestone owner` | Plain text |
| Milestone Type | `customfield_13056` | `Type` | Pass as-is — options: `Implementation`, `Culture`, `Money Step` |
| Planning summary | `customfield_13057` | `Planning summary` | Pass as-is — options: `Not started`, `Completed` |
| Milestone work starting date | `customfield_13058` | `Work starting date` | `yyyy-mm-dd` |
| Milestone completion date | `customfield_13059` | `Milestone completion date` | `yyyy-mm-dd` |
| Cross-functional support needed | `customfield_12569` | `Cross-functional support needed` | Strip person names: `Marketing (Desere Wolfe)` → `Marketing` |
| Initiative (link) | `customfield_13065` | `Initiative information` (name only) | Cannot be set on create — requires separate API call after creation. Look up KIWI key from initiative name |

### Columns intentionally NOT mapped

| Wave Column | Reason |
|---|---|
| `Description and purpose` | Mapped to description — drop original column |
| `Initiative information` | Used for split logic only; not a JPD field |

---

## Multi-Select Field Delimiter

Wave exports use `; ` (semicolon + space) as the delimiter for multi-value fields:

```
"Tech; Finance; HR"  →  ["Tech", "Finance", "HR"]
```

**For CSV import:** repeat the column header N times (one column per value)  
**For API:** send as array `[{"value": "Tech"}, {"value": "Finance"}, {"value": "HR"}]`

---

## Known Value Corrections

| Field | Wave Value | JPD Value | Notes |
|---|---|---|---|
| Accountable Workstream | `Procured spend` | `Procured Spend` | Capitalisation fix |
| Sequencing prioritization | `Foundational` | `Foundational` | Pass through — values match since JPD field was updated |
| Cross-functional support (Milestones) | `Marketing (Desere Wolfe)` | `Marketing` | Strip person name in parentheses |
| Is this a Revenue Initiative? | `Yes` | `1` | Checkbox field requires numeric |
| Is this a Revenue Initiative? | `No` | `0` | Checkbox field requires numeric |
