#!/usr/bin/env python3
"""
Wave → JPD Transform Script
E.W. Scripps — KIWI Project

Transforms Wave Excel exports into Jira Product Discovery import-ready CSVs.
Handles both Initiative and Milestone issue types.

Usage:
  python3 transform.py --input file.xlsx --type initiative --output output.csv
  python3 transform.py --input file.xlsx --type milestone --output output/ --split
"""

import argparse
import csv
import html
import io
import re
import sys
from pathlib import Path

import pandas as pd


# ──────────────────────────────────────────────
# MARKDOWN → JIRA WIKI MARKUP CONVERSION
# ──────────────────────────────────────────────

def md_to_jira(text):
    """Convert markdown and clean HTML to Jira wiki markup."""
    if pd.isna(text) or str(text).strip() == 'nan':
        return ''
    text = str(text)
    # Clean HTML artifacts
    text = html.unescape(text)
    text = re.sub(r'<[^>]+>', '', text)
    text = text.replace('\xa0', ' ').replace('\\~', '~')
    # Headings — deepest first to avoid double-conversion
    text = re.sub(r'^### (.+)$', r'h3. \1', text, flags=re.MULTILINE)
    text = re.sub(r'^## (.+)$',  r'h2. \1', text, flags=re.MULTILINE)
    text = re.sub(r'^# (.+)$',   r'h1. \1', text, flags=re.MULTILINE)
    # Bold: **text** → *text*
    text = re.sub(r'\*\*(.+?)\*\*', r'*\1*', text, flags=re.DOTALL)
    # Inline italic: *text* when NOT at line start (list bullets)
    text = re.sub(r'(?<=\S)\*(.+?)\*(?=\S|$)', r'_\1_', text)
    text = re.sub(r'(?<=\s)\*(\S.+?\S)\*(?=[\s.,;:!?])', r'_\1_', text)
    # Strip orphaned ** markers
    text = re.sub(r'\*{2,}', '', text)
    # Numbered lists: "1. item" → "# item"
    text = re.sub(r'^\s*\d+\.\s+', '# ', text, flags=re.MULTILINE)
    # Dash bullets: "- item" → "* item"
    text = re.sub(r'^- ', '* ', text, flags=re.MULTILINE)
    # Markdown tables → Jira tables
    def convert_table(match):
        lines = [l for l in match.group(0).strip().split('\n')
                 if not re.match(r'^\|[-| :]+\|$', l)]
        result = []
        for i, line in enumerate(lines):
            cells = [c.strip() for c in line.strip('|').split('|')]
            result.append(('||' + '||'.join(cells) + '||') if i == 0
                          else ('|' + '|'.join(cells) + '|'))
        return '\n'.join(result)
    text = re.sub(r'(\|.+\|\n?)+', convert_table, text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


# ──────────────────────────────────────────────
# SHARED UTILITIES
# ──────────────────────────────────────────────

def format_date(val):
    """Format datetime to yyyy-mm-dd string."""
    if pd.isna(val):
        return ''
    return val.strftime('%Y-%m-%d')


def format_number(val):
    """Round float to 2dp, return int if whole number. Fixes Excel precision artifacts."""
    if pd.isna(val):
        return ''
    fv = round(float(val), 2)
    return int(fv) if fv == int(fv) else fv


def explode_multiselect(series, delimiter='; '):
    """Split semicolon-delimited values into repeated columns for CSV import."""
    split = series.fillna('').apply(
        lambda x: [v.strip() for v in str(x).split(delimiter) if v.strip()]
    )
    max_vals = split.apply(len).max() or 1
    cols = [split.apply(lambda x: x[i] if i < len(x) else '') for i in range(max_vals)]
    return cols, max_vals


def write_csv(df_cols, header_names, rows_data, output_path):
    """Write CSV with proper quoting."""
    out = io.StringIO()
    writer = csv.writer(out, quoting=csv.QUOTE_MINIMAL)
    writer.writerow(header_names)
    for row in rows_data:
        writer.writerow(['' if pd.isna(v) else v for v in row])
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(out.getvalue())


# ──────────────────────────────────────────────
# INITIATIVE TRANSFORM
# ──────────────────────────────────────────────

# Columns merged into description — do NOT map these separately in Jira importer
INITIATIVE_DESC_COLS = {
    'initiative': 'Description of Initiative – be specific, what are we actually changing that creates value',
    'functional': 'Functional requirements needed for the Initiative',
    'tech':       'Tech Sequencing notes',
    'legal':      'Regulatory rules or laws that must be fulfilled by Tech work',
}

# Accountable Workstream value corrections
AW_VALUE_MAP = {
    'Procured spend': 'Procured Spend',
    # Full combined value is valid as a single option in JPD — pass through as-is
}


def build_initiative_description(row):
    parts = [
        f"h2. Initiative Description\n{md_to_jira(row[INITIATIVE_DESC_COLS['initiative']])}",
        f"h2. Functional Requirements\n{md_to_jira(row[INITIATIVE_DESC_COLS['functional']])}",
        f"h2. Tech Sequencing Notes\n{md_to_jira(row[INITIATIVE_DESC_COLS['tech']])}",
        f"h2. Legal & Regulatory Requirements\n{md_to_jira(row[INITIATIVE_DESC_COLS['legal']])}",
    ]
    return '\n\n'.join(parts)


def transform_initiatives(df, output_path):
    df = df.copy()

    # Build merged description
    df['JPD Description'] = df.apply(build_initiative_description, axis=1)

    # Blank out the legal standalone field (content merged into description)
    legal_col = INITIATIVE_DESC_COLS['legal']
    df[legal_col] = ''

    # Date
    df['(LW) L4 latest estimated date'] = df['(LW) L4 latest estimated date'].apply(format_date)

    # Revenue Initiative: Yes→1, No→0
    df['Is this a Revenue Initiative?'] = df['Is this a Revenue Initiative?'].apply(
        lambda v: '' if pd.isna(v) else ('1' if str(v).strip().lower() == 'yes' else '0')
    )

    # Accountable Workstream value corrections (single column)
    df['Accountable Workstream'] = df['Accountable Workstream'].apply(
        lambda v: AW_VALUE_MAP.get(str(v).strip(), str(v).strip()) if not pd.isna(v) else ''
    )

    # Explode multi-select columns
    cf_cols, cf_max = explode_multiselect(df['Cross-functional support needed'])
    fd_cols, fd_max = explode_multiselect(df['Functional dependency'])
    df = df.drop(columns=['Cross-functional support needed', 'Functional dependency'])

    # Insert Issue Type after Name
    df.insert(list(df.columns).index('Name') + 1, 'Issue Type', 'Initiative')
    output_cols = list(df.columns)

    # Build header and rows
    header = (output_cols
              + ['Cross-functional support needed'] * cf_max
              + ['Functional dependency'] * fd_max)

    rows = []
    net_col  = 'Net recurring benefits (latest estimate, annualized)'
    impl_col = '(LW) Implementation costs (latest estimate, annualized)'

    for idx, row in df.iterrows():
        base = []
        for c in output_cols:
            v = row[c]
            if c in (net_col, impl_col):
                base.append(format_number(v))
            elif pd.isna(v):
                base.append('')
            else:
                base.append(v)
        base += ['' if s.iloc[idx] == '' else s.iloc[idx] for s in cf_cols]
        base += ['' if s.iloc[idx] == '' else s.iloc[idx] for s in fd_cols]
        rows.append(base)

    write_csv(output_cols, header, rows, output_path)
    print(f"  Initiatives: {len(rows)} rows, {len(header)} columns → {output_path}")


# ──────────────────────────────────────────────
# MILESTONE TRANSFORM
# ──────────────────────────────────────────────

def strip_person_name(val):
    """'Marketing (Desere Wolfe)' → 'Marketing'"""
    if pd.isna(val) or str(val).strip() == 'nan':
        return ''
    return re.sub(r'\s*\(.*?\)', '', str(val)).strip()


def build_milestone_description(row):
    desc = md_to_jira(row.get('Description and purpose', ''))
    return f"h2. Description and Purpose\n{desc}"


def transform_milestones(df, output_path_or_dir, split=False):
    df = df.copy()

    if split:
        # Split by Initiative information value
        groups = {}
        for val in df['Initiative information'].dropna().unique():
            subset = df[df['Initiative information'] == val].copy()
            # Extract initiative name from "Name: X -- L3 date: ..."
            match = re.search(r'Name:\s*(.+?)\s*--', val)
            name = match.group(1).strip() if match else val[:40]
            slug = re.sub(r'[^a-z0-9]+', '_', name.lower()).strip('_')
            groups[slug] = subset
        for slug, subset in groups.items():
            out_file = Path(output_path_or_dir) / f"milestones_{slug}_import_ready.csv"
            _transform_milestone_df(subset, str(out_file))
    else:
        _transform_milestone_df(df, output_path_or_dir)


def _transform_milestone_df(df, output_path):
    df = df.copy()

    df['JPD Description'] = df.apply(build_milestone_description, axis=1)
    df['Work starting date'] = df['Work starting date'].apply(format_date)
    df['Milestone completion date'] = df['Milestone completion date'].apply(format_date)
    df['Cross-functional support needed'] = df['Cross-functional support needed'].apply(strip_person_name)

    # Drop source columns not needed in output
    drop_cols = ['Initiative information', 'Description and purpose']
    df = df.drop(columns=[c for c in drop_cols if c in df.columns])

    # Rename to match JPD field names
    df = df.rename(columns={
        '#':                          'Milestone ID',
        'Milestone owner':            'Milestone Owner',
        'Type':                       'Milestone Type',
        'Work starting date':         'Milestone work starting date',
        'Milestone completion date':  'Milestone completion date',
        'Planning summary':           'Planning summary',
    })

    # Insert Issue Type after Name
    df.insert(list(df.columns).index('Name') + 1, 'Issue Type', 'Milestone')

    output_cols = ['Milestone ID', 'Name', 'Issue Type', 'Milestone Owner', 'Milestone Type',
                   'Status', 'Milestone work starting date', 'Milestone completion date',
                   'Planning summary', 'Cross-functional support needed', 'JPD Description']
    # Only keep columns that exist
    output_cols = [c for c in output_cols if c in df.columns]
    df = df[output_cols]

    rows = [['' if pd.isna(v) else v for v in row] for _, row in df.iterrows()]
    write_csv(output_cols, output_cols, rows, output_path)
    print(f"  Milestones: {len(rows)} rows → {output_path}")


# ──────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='Wave → JPD transform')
    parser.add_argument('--input',  required=True, help='Path to Wave xlsx or csv export')
    parser.add_argument('--type',   required=True, choices=['initiative', 'milestone'],
                        help='Issue type to transform')
    parser.add_argument('--output', required=True, help='Output CSV path (or dir if --split)')
    parser.add_argument('--split',  action='store_true',
                        help='Milestones only: split into one CSV per initiative')
    args = parser.parse_args()

    print(f"Loading {args.input}...")
    if args.input.endswith('.csv'):
        df = pd.read_csv(args.input)
    else:
        df = pd.read_excel(args.input)
    print(f"  {len(df)} rows, {len(df.columns)} columns")

    if args.type == 'initiative':
        transform_initiatives(df, args.output)
    else:
        transform_milestones(df, args.output, split=args.split)

    print("Done.")


if __name__ == '__main__':
    main()
