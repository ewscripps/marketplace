# Platforms

Everything OS-specific lives here. The rest of the skill assumes the tools are present
and the two credential variables are set.

**Claude Code on Windows runs its Bash tool through Git Bash**, so when the agent runs a
command it has bash, `grep`, `sed` and a working `/tmp`. Without Git for Windows it
falls back to a PowerShell tool. The commands below are what a **human** needs in their
own shell, which is where the differences bite.

## Prerequisites

| | macOS | Linux / WSL2 | Windows |
|---|---|---|---|
| Graphviz | `brew install graphviz` | `sudo apt install graphviz` | `winget install Graphviz.Graphviz` |
| Python | preinstalled | preinstalled | [python.org](https://www.python.org/downloads/) — tick **Add to PATH** |
| Invoke Python as | `python3` | `python3` | `py -3` |
| Git Bash | — | — | required by Claude Code |

**Use `py -3` on Windows, not `python3`.** Windows 10/11 ship an App Execution Alias
named `python3.exe` that opens the Microsoft Store and exits without running anything —
so a `python3` call appears to succeed while doing nothing at all. The `py` launcher is
the only reliably present name.

## Credentials

The contract is only this: **`ATLASSIAN_EMAIL` and `ATLASSIAN_API_TOKEN` must be in the
environment.** How they get there is your shell's business.

```bash
# macOS / Linux / WSL / Git Bash
source ~/.zshenv          # macOS: these live in ~/.config/zsh/secrets.zsh
```

```powershell
# PowerShell, current session
$env:ATLASSIAN_EMAIL = 'you@scripps.com'
$env:ATLASSIAN_API_TOKEN = '...'

# PowerShell, persistent — add to $PROFILE, or set once at user scope:
[Environment]::SetEnvironmentVariable('ATLASSIAN_EMAIL', 'you@scripps.com', 'User')
```

They are deliberately not exported into non-interactive shells on macOS, which is why a
script that works in your terminal can fail under an agent. Source them first.

Get a token from <https://id.atlassian.com/manage-profile/security/api-tokens>. Never
commit it or echo it into a page body.

## Installing the skill

**Preferred: the plugin.** It installs infra-docs and asd-ste100 together and updates
through `/plugin`, identically on every OS:

```
/plugin marketplace add git@gitlab.com:scripps/public/marketplace.git
/plugin install infra-docs@stg-marketplace
```

**Manual fallback.** Claude Code looks in `~/.claude/skills/<name>/SKILL.md`, which on
Windows is `%USERPROFILE%\.claude\skills\`. Install **both** skills as siblings —
infra-docs reads `../asd-ste100/` when the Skill call is unavailable. Run from
`plugins/infra-docs/skills/` in a clone of the marketplace repo:

```bash
# macOS / Linux / WSL / Git Bash — link, so repo edits take effect immediately
ln -sfn "$PWD/infra-docs" ~/.claude/skills/infra-docs
ln -sfn "$PWD/asd-ste100" ~/.claude/skills/asd-ste100
```

```powershell
# Windows, recommended: a directory junction. No elevation, no Developer Mode.
cmd /c mklink /J "$env:USERPROFILE\.claude\skills\infra-docs" "$PWD\infra-docs"
cmd /c mklink /J "$env:USERPROFILE\.claude\skills\asd-ste100" "$PWD\asd-ste100"
```

A real symlink (`New-Item -ItemType SymbolicLink`, or `mklink /D`) needs Administrator
unless Developer Mode is on, which is why the junction is the better default. If neither
is available, copy instead and re-copy when the skills change:

```powershell
Copy-Item -Recurse -Force infra-docs, asd-ste100 "$env:USERPROFILE\.claude\skills\"
```

Do not keep a manual copy alongside the plugin — both copies load, and they drift apart
the moment the plugin updates.

> If a symlink is ever committed into a repo, Git for Windows defaults to
> `core.symlinks=false` and checks it out as a **text file containing the target path**.
> The skill would silently not load.

## Graphviz on Windows

`winget install Graphviz.Graphviz` handles PATH. Two failures are worth recognising.

**`Format: svg not recognized`** — the installer did not register the plugins. This hits
exactly the output format this standard requires. Fix from an **elevated** prompt:

```
dot -c
```

**`'dot' is not recognized`** — Graphviz is installed but not on PATH. Add
`C:\Program Files\Graphviz\bin`, or reinstall via winget.

On a locked-down machine where no installer can run, the portable ZIP from
[graphviz.org/download](https://graphviz.org/download/) works: unzip it anywhere and set
`GVBINDIR` to its `bin` directory. That avoids both admin rights and the registry, so
the `dot -c` problem cannot occur.

## Shell gotchas

**`^` is the escape character in cmd.exe.** The refresh workflow validates a commit with
`git cat-file -e <sha>^{commit}`. Unquoted in cmd that becomes `<sha>{commit}`, git
reports an invalid object, and the run misreads it as *SHA unreachable* and quietly
downgrades to DEGRADED mode. Always quote it:

```bash
git cat-file -e "<sha>^{commit}"
```

PowerShell, Git Bash and macOS are unaffected.

**`~` is not expanded for native executables in PowerShell.** `--file ~/page.html`
reaches Python as a literal `~`. `confluence.py` calls `expanduser` so it works anyway,
but prefer full paths in PowerShell.

**Fonts.** `diagram-preamble.dot` asks for `Arial,Helvetica,sans-serif` rather than
`Helvetica`, because Helvetica is not installed on Windows and Graphviz substitutes —
changing every text width, every coordinate, and therefore the measured legibility
figures. Expect small SVG diffs between a Mac-rendered and a Windows-rendered file even
with no source change. If a diff is all coordinates and no content, that is why.

## Windows smoke test

Run this once on a new Windows machine. It exercises every failure mode above.

```powershell
winget install Graphviz.Graphviz
dot -V                                    # 'not recognized' -> PATH
echo "digraph{a->b}" | dot -Tsvg -o t.svg # 'Format: svg not recognized' -> elevated dot -c

py -3 render.py                           # renders + legibility check, no bash needed
py -3 assets\confluence.py verify --page 3822780417
```

The one that actually proves the encoding fix: **publish a page whose title or body
contains an em-dash, then look at it.** If it shows `â€"` instead of `—`, the UTF-8
handling regressed.
