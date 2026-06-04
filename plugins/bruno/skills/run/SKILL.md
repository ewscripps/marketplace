---
name: run
description: Run a Bruno collection, folder, or single request using the bru CLI with environment and output format selection
user-invocable: true
argument-hint: '[path/to/request.yml | path/to/folder/]'
allowed-tools: Bash(bru *), Bash(find *), Read, Glob, Grep, AskUserQuestion
---

# Run a Bruno Collection

Execute Bruno API requests or collections using the `bru` CLI. Prefers OpenCollection YAML format (`.yml`) but supports legacy `.bru` collections transparently.

## Step 1: Check for bru CLI

Run `command -v bru` to check if the CLI is installed.

If not installed, inform the user:

> The `bru` CLI is not installed. Install it with:
> ```
> npm install -g @usebruno/cli
> ```
> Then re-run this skill.

Stop if the CLI is unavailable.

## Step 2: Locate the Collection Root

Check `$ARGUMENTS` first — if a path is provided, use it as the starting point.

Otherwise, search for a collection root starting from the current directory. Run these in parallel:

```
find . -name "opencollection.yml" -not -path "*/node_modules/*" -maxdepth 6
find . -name "bruno.json" -not -path "*/node_modules/*" -maxdepth 6
```

Prefer `opencollection.yml` (YAML format). Fall back to `bruno.json` (legacy). Use the parent directory of the discovered file as the collection root.

- If exactly one collection is found, use it.
- If multiple are found, use AskUserQuestion to let the user pick.
- If none is found, inform the user that no Bruno collection was detected and stop.

## Step 3: Determine What to Run

If `$ARGUMENTS` was a path to a specific `.yml` request file, target it directly and skip to Step 4.

Otherwise, list the collection structure. Run in parallel:

```
find <collection-root> -name "*.yml" -not -path "*/environments/*" -not -name "opencollection.yml" -not -name "folder.yml" | sort
find <collection-root> -name "*.bru" -not -path "*/environments/*" -not -name "collection.bru" | sort
```

Use AskUserQuestion to ask what to run:

- **Entire collection** — run all requests recursively from the collection root
- **A specific folder** — show a numbered list of subdirectories and let the user pick
- **A single request** — show a numbered list of all request files and let the user pick one

Present up to 10 entries. If there are more than 10, show the 10 most recently modified and note the total count.

## Step 4: Select an Environment

List available environments:

```
find <collection-root>/environments -name "*.yml" 2>/dev/null | sort
```

Extract environment names by stripping the `.yml` extension from each filename.

If environments are found, use AskUserQuestion to select one:
- List each environment name as an option
- Include a **"No environment"** option at the end

If no `environments/` directory exists, proceed without one.

## Step 5: Configure Run Options

Use AskUserQuestion to select output format:

- **Terminal only** — no `--output` flag; results print to stdout
- **JSON report** — adds `--output results.json --format json`
- **JUnit XML** — adds `--output results.xml --format junit`
- **HTML report** — adds `--output results.html --format html`

Then ask: **Scope?**
- **Run all requests** — no extra flag
- **Tests only** — adds `--tests-only`

If the collection's pre-request scripts use `require()`, npm packages, or file system access, note that `--sandbox=developer` is required. Ask the user to confirm if they need it.

## Step 6: Build and Execute the Command

Assemble the `bru run` command:

```
bru run <target> [--env <env-name>] [--output <file> --format <format>] [--tests-only] [--recursive] [--sandbox developer]
```

Where `<target>` and flags are:
- **Single request** — specific `.yml` file path; no `--recursive`
- **Folder** — folder path; no `--recursive`
- **Entire collection** — collection root path; add `--recursive`

Show the exact command to the user before running, then execute it.

## Step 7: Display Results

After execution, display:

- **Summary**: total requests, passed, failed
- **Failed requests**: request name, HTTP status, and assertion/test failure message
- **Test results**: assertions passed/failed count
- **Exit code meaning**: 0 = success, 1 = test failures, 2–9 = config/file errors

If an output file was generated, confirm its path.
