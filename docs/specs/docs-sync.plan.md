# docs-sync Agent and Hook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the README package table and the key bindings list in sync with `packages.yaml` and the PowerShell
profile files through a `docs-sync` Claude Code agent triggered by a `PostToolUse` hook.

**Architecture:** A category glossary (docs + YAML group comments) gives the agent its only classification input.
A small Python hook script matches edited paths and injects an `additionalContext` reminder; the `docs-sync`
subagent rewrites only the marker-delimited regions of two Markdown files. The first agent run is the one-time
correction of both documents.

**Tech Stack:** Claude Code hooks and subagents, Python 3 (stdlib only), chezmoi. No new test tooling (manual smoke checks).

**Spec:** [`docs/specs/docs-sync.md`](docs-sync.md) (R1–R10, D1–D9, A1–A7)

## Global Constraints

- Branch `docs/17-docs-sync-agent` off `develop`. Conventional Commits with a scope; the last commit carries
  `Fixes #17`. Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Run chezmoi with `--source .` from the repo root. Never run `chezmoi apply` or `install.ps1` on the host.
- Line endings (`.editorconfig`): `*.md`, `*.py`, `*.json`, `*.yaml` are **LF**; do not change existing endings.
- No new test framework, test directory or dependency is added to the repo (decision 2026-10-16).
- No change under `home/` except **comments and blank lines** in `home/.chezmoidata/packages.yaml` (Task 1).
- No plaintext secrets; do not touch `*.age` / `encrypted_*`.
- `.claude/settings.local.json` is not modified (its Rider hook is already broken, see Hand-off).
- The hook uses no network and no `chezmoi`; the agent never edits `home/`.
- Glossary, exact: `shell`, `fzf`, `git`, `dotnet`, `node`, `containers`, `chezmoi`, `editors`, `browsers`, `other`.
- Hook command, exact: `python3 "$CLAUDE_PROJECT_DIR/.claude/hooks/docs-sync-trigger.py"`.
- Markers, exact: `<!-- BEGIN:packages -->` / `<!-- END:packages -->` (ReadMe.md);
  `<!-- BEGIN:bindings -->` / `<!-- END:bindings -->` (docs/terminal-bindings.md).

## Review Focus

1. **Path-match variants** — `packages.yaml.bak`, `PSReadLine_profile.ps1.tmpl`, `check-updates.ps1.tmpl`, Windows
   backslash paths, absolute paths inside `.claude/worktrees/...`. Expected: only the two exact targets match.
   Owned by Task 2, Step 3 (manual smoke check).
2. **Garbage hook input** — empty stdin, non-JSON, JSON without `tool_input`, non-string `file_path`. Expected:
   no output, exit 0, no traceback. Owned by Task 2, Step 3 (manual smoke check).
3. **Damaged markers** — a missing, duplicated or reversed marker. Expected: the agent reports it and edits nothing
   (it must never append the table elsewhere). Owned by Task 3 (prompt rule) and Task 4 (mutation check).
4. **Unknown or missing group comment** — an id under `# unknown`, or above any comment. Expected: listed in the
   agent's final message, absent from the table. Owned by Task 4 (mutation check).
5. **Rerun drift** — a second run on unchanged sources rewording cells or reordering rows. Expected: empty
   `git diff`. Owned by Task 4.

---

### Task 1: Category glossary and group comments

**Files:**
- Modify: `home/.chezmoidata/packages.yaml` (comments and blank lines only)
- Modify: `docs/packages.md` (add glossary section)

**Interfaces:**
- Produces: the glossary (Global Constraints) in `docs/packages.md`, and a group comment above every id of every list
  in `packages.yaml`. Tasks 3–4 rely on both.

- [ ] **Step 1: Capture the baseline**

```powershell
Get-Content -Raw home/.chezmoitemplates/config.dsc.yaml.tmpl | chezmoi --source . execute-template > $env:CLAUDE_JOB_DIR/tmp/dsc.before.yaml
```

Expected: non-empty file. (If `$env:CLAUDE_JOB_DIR` is unset, use any scratch path outside the repo.)

- [ ] **Step 2: Add a "Categories" section to `docs/packages.md`**

One line per glossary name (what belongs there), stating that the names are the only allowed values for the group
comments in `packages.yaml` and for the README *Category* column. Replace nothing else in this task.

- [ ] **Step 3: Add group comments in `packages.yaml` per spec D1/D2**

`windows.modules` split into `# shell` (Microsoft.WinGet.Client, Terminal-Icons), `# fzf` (PSfzf), `# git`
(posh-git), `# containers` (DockerCompletion), `# other` (powershell-yaml, Pester); `dotnet_tools` → `# dotnet`;
`yazi_plugins` → `# shell`; `windows.wsl` → `# other` (a comment line above the key); rename `# Node JS` → `# node`,
`# docker` (windows and linux) → `# containers`. Do not reorder or add/remove ids; blank lines between groups as in
`wingets`.

- [ ] **Step 4: Verify the rendered DSC document is unchanged (A1)**

```powershell
Get-Content -Raw home/.chezmoitemplates/config.dsc.yaml.tmpl | chezmoi --source . execute-template > $env:CLAUDE_JOB_DIR/tmp/dsc.after.yaml
fc.exe $env:CLAUDE_JOB_DIR/tmp/dsc.before.yaml $env:CLAUDE_JOB_DIR/tmp/dsc.after.yaml
git diff -U0 home/.chezmoidata/packages.yaml | Select-String '^[+-](?!\s*#|\s*$|\+\+|--)'
```

Expected: `fc.exe` reports "no differences"; the `Select-String` prints nothing.

- [ ] **Step 5: Verify every group comment is in the glossary**

```powershell
Select-String -Path home/.chezmoidata/packages.yaml -Pattern '^\s+#\s*(\S.*)$' | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() } | Sort-Object -Unique
```

Expected: a subset of the ten glossary names, nothing else.

- [ ] **Step 6: Commit**

```bash
git add home/.chezmoidata/packages.yaml docs/packages.md
git commit -m "docs(packages): define category glossary and group every package list" -m "Refs #17"
```

---

### Task 2: Path-match hook

**Files:**
- Create: `.claude/hooks/docs-sync-trigger.py`
- Create: `.claude/settings.json`

No automated tests: one small script does not justify a new test tool in the repo. It is verified by the manual
smoke check in Step 3 and the live trigger in Task 4, Step 5. Add Pester tests only if the hook starts failing in
practice.

**Interfaces:**
- Produces: `docs-sync-trigger.py` — reads one Claude Code `PostToolUse` JSON object on stdin; contains
  `def is_sync_source(path: str) -> bool` and `def main() -> int`; prints one JSON object (spec R8) iff
  `is_sync_source(tool_input.file_path)`; always returns 0. The printed `additionalContext` names the `docs-sync`
  agent and the matched path. Task 3's agent file must be named `docs-sync` so the text is actionable.
- Consumes: nothing.

- [ ] **Step 1: Implement `docs-sync-trigger.py`**

Stdlib only. `is_sync_source`: normalise `\` to `/`, then match (`re.search`) `(^|/)home/\.chezmoidata/packages\.yaml$`
or `(^|/)home/dot_profile/[^/]+\.ps1$`. `main`: wrap everything in `try/except Exception` and return 0 on any
error; read `json.load(sys.stdin)`; require `tool_input.file_path` to be a `str`. Emit with `json.dump` +
newline. Script ends with `sys.exit(main())` under `__main__`.

- [ ] **Step 2: Create `.claude/settings.json`**

Two-space-indented JSON with `hooks.PostToolUse` = one entry, `matcher: "Edit|Write"`, one `command` hook with the
exact command from Global Constraints. Nothing else in the file.

- [ ] **Step 3: Smoke check (manual, run once, not committed)**

```powershell
Get-Content -Raw .claude/settings.json | ConvertFrom-Json | Out-Null
$cases = @(
  '{"tool_input":{"file_path":"home/.chezmoidata/packages.yaml"}}',
  '{"tool_input":{"file_path":"C:\\repo\\home\\dot_profile\\psfzf_profile.ps1"}}',
  '{"tool_input":{"file_path":"/r/.claude/worktrees/x/home/.chezmoidata/packages.yaml"}}',
  '{"tool_input":{"file_path":"ReadMe.md"}}',
  '{"tool_input":{"file_path":"home/.chezmoidata/packages.yaml.bak"}}',
  '{"tool_input":{"file_path":"home/dot_profile/check-updates.ps1.tmpl"}}',
  '', 'not json', '{"tool_input":{"file_path":42}}'
)
foreach ($c in $cases) { "--- $c"; $c | python3 .claude/hooks/docs-sync-trigger.py; "exit=$LASTEXITCODE" }
```

Expected: no parse error; the first three print one JSON line containing `docs-sync`; the other six print
nothing; every `exit=0`. The live trigger (A6) cannot be tested in this session (settings are read at session
start); it is Task 4, Step 5.

- [ ] **Step 4: Commit**

```bash
git add .claude/hooks/docs-sync-trigger.py .claude/settings.json
git commit -m "feat(claude): hook that asks for docs-sync after package or profile edits" -m "Refs #17"
```

---

### Task 3: `docs-sync` agent, markers, and docs

**Files:**
- Create: `.claude/agents/docs-sync.md`
- Modify: `ReadMe.md` (wrap the existing table in the packages markers)
- Modify: `docs/terminal-bindings.md` (wrap the existing sections in the bindings markers)
- Modify: `docs/packages.md` (replace the "manual mirror" bullet)
- Modify: `docs/architecture.md` (one capability-table row), `docs/conventions.md` (one short section)

**Interfaces:**
- Consumes: glossary and group comments (Task 1); the agent name `docs-sync` (Task 2's reminder text).
- Produces: subagent `docs-sync` with frontmatter `name: docs-sync`, `description` (when to run: after edits to
  `packages.yaml` or `home/dot_profile/*.ps1`; what it touches), `tools: Read, Edit, Grep, Glob, WebFetch`,
  `model: sonnet`. No `Bash`, no `Write` — it can only modify existing files by `Edit`.

- [ ] **Step 1: Put the markers around the existing content**

In `ReadMe.md`, `<!-- BEGIN:packages -->` on its own line directly above the table header and `<!-- END:packages -->`
directly below the last row (blank line outside, none inside). In `docs/terminal-bindings.md`, wrap from the first
`##` section to the last table row. Leave everything else, including the `docs/bindings.md` link (#25), unchanged.

- [ ] **Step 2: Write the agent prompt** in `.claude/agents/docs-sync.md`

The body must state, in this order, each item below (spec reference in brackets); write imperative instructions,
not narrative:
1. Inputs to read: `packages.yaml`, the glossary in `docs/packages.md`, the current README table, the two profile
   files; sources of truth and what is output-only. [R3–R5]
2. Marker contract: edit only between markers; if a marker is missing, duplicated, or out of order, **stop, report,
   edit nothing**; never touch `home/`, `packages.yaml`, or anything outside the regions. [R3]
3. Packages algorithm: row-per-id rule, columns, Install Type values, category from the nearest group comment,
   drop removed ids, report unknown/missing groups and leave them out, row order D3, copy existing *Name* and
   *Purpose* cells verbatim, write new ones as `Display name (winget id)` / short purpose in the existing style. [R4, D3, D4]
4. Bindings algorithm: columns and `Source` values with the D6 rules; inputs listed in R5; the **seed defaults**
   list (D5: `Ctrl+]` GotoBrace, `Ctrl+h` BackwardDeleteChar, `Alt+.` YankLastArg, `Alt+a` SelectCommandArgument,
   `Ctrl+l` ClearScreen, `Ctrl+z` Undo, `Ctrl+y` Redo, `F7` History); verify each default and each PSFzf chord
   (including every `-GitKeyBindings` chord) against the PSReadLine/PSFzf documentation with `WebFetch`; report what
   cannot be verified; action text is one plain sentence, existing action cells are kept verbatim. [R5–R7]
5. Idempotence rule: no source change ⇒ no diff. [R7, D4]
6. Final message format: files changed, rows added/removed per document, and a "Reported" list (unknown groups,
   unverifiable bindings, marker problems).

- [ ] **Step 3: Update the docs (R10)**

`docs/packages.md`: replace the "manual mirror" bullet with one stating that the table between the packages markers
in `ReadMe.md` is generated by the `docs-sync` agent from `packages.yaml` (ids, categories) and keeps hand-written
names/purposes. `docs/architecture.md`: one row in the capabilities table (documentation kept in sync: start from
`.claude/agents/docs-sync.md` and `.claude/hooks/docs-sync-trigger.py`). `docs/conventions.md`: a "Generated
documentation" section — text between `BEGIN:`/`END:` markers is overwritten by the agent; edit the source or the
agent prompt instead; the hook only reminds, so run the agent yourself after edits made outside Claude Code.

- [ ] **Step 4: Verify structure**

```powershell
Select-String -Path ReadMe.md,docs/terminal-bindings.md -Pattern '<!-- (BEGIN|END):(packages|bindings) -->'
Select-String -Path docs/packages.md -Pattern 'manual mirror'
Select-String -Path docs/architecture.md,docs/conventions.md -Pattern 'docs-sync'
Get-Content .claude/agents/docs-sync.md -TotalCount 8
```

Expected: exactly 2 marker lines per file; no `manual mirror` match; `docs-sync` found in both docs; frontmatter has
the four fields above.

- [ ] **Step 5: Commit**

```bash
git add .claude/agents/docs-sync.md ReadMe.md docs/terminal-bindings.md docs/packages.md docs/architecture.md docs/conventions.md
git commit -m "feat(claude): docs-sync agent and generated-region markers" -m "Refs #17"
```

---

### Task 4: First run, idempotence, mutation checks, live trigger

**Files:**
- Modify (by the agent): `ReadMe.md`, `docs/terminal-bindings.md` — inside the markers only.

**Interfaces:**
- Consumes: everything above. Produces: the corrected documents (A3) and evidence for A4–A6.

- [ ] **Step 1: Check the AIChat precondition**

Run: `Select-String -Path home/.chezmoidata/packages.yaml -Pattern 'AIChat'; gh issue view 21 --json state --jq .state`
Expected: if AIChat is still listed, **stop and ask the user** whether to land #21 first (spec "Risks"). Do not add an ignore rule.

- [ ] **Step 2: First run (A3)**

Run the `docs-sync` agent in this session (Agent tool, `subagent_type: "docs-sync"`; if the new agent is not yet
registered, restart the session or run a general-purpose agent whose prompt is the body of
`.claude/agents/docs-sync.md`). Then verify:

```powershell
git diff --stat
git diff -U0 ReadMe.md docs/terminal-bindings.md | Select-String '^@@'
```

Expected: only the two files changed; every hunk lies between the markers (compare hunk line numbers with the
marker line numbers from `Select-String`). README row count = ids in `wingets` + `modules` + `dotnet_tools` +
`yazi_plugins` + 1 (`wsl`); `GnuWin32.File` and `.NET SDK 9` absent; the bindings table contains `Alt+c`, `Ctrl+r`,
`Ctrl+t`, `Ctrl+s`, `Ctrl+Alt+c`, `UpArrow`, `DownArrow` with the sources from the profile files.

- [ ] **Step 3: Idempotence (A4)**

Stage the Step 2 output (`git add ReadMe.md docs/terminal-bindings.md`), run the agent again, then `git diff`
(unstaged changes only).
Expected: empty. If not empty, tighten the prompt rule (D4) and repeat from Step 2.

- [ ] **Step 4: Mutation checks (A5, Review Focus 3–4)** — all on the working tree, reverted with `git restore`

(a) Delete the id `Microsoft.PowerToys` from `packages.yaml`, run the agent → its row is gone. (b) Add `- Foo.Bar` under a new `# unknown` group → final message lists it; no row added.
(c) Delete `<!-- END:packages -->` → agent reports the marker problem and `git diff ReadMe.md` is empty.
Revert each with `git restore home/.chezmoidata/packages.yaml ReadMe.md` before the next; confirm clean afterwards
(except the staged Step 2 output).

- [ ] **Step 5: Live hook trigger (A6)** — needs a new session

Start a fresh Claude Code session in the repo, make a trivial comment edit in `packages.yaml` and observe the
reminder; edit `docs/conventions.md` and observe none. Record which shell ran the hook (does `$CLAUDE_PROJECT_DIR`
expand?) and whether it pointed at the worktree. If the command fails, fix the command string in
`.claude/settings.json` (e.g. fall back to a `.claude/hooks/...` path relative to the cwd) and update spec "Risks".
Revert the trial edits.

- [ ] **Step 6: Final checks and commit**

```powershell
chezmoi --source . managed | Measure-Object
git status --short
```

Expected: `managed` runs without error; status shows only intended files.

```bash
git add ReadMe.md docs/terminal-bindings.md
git commit -m "docs: regenerate package table and key bindings with docs-sync" -m "Fixes #17"
```

---

## Hand-off notes

- **Existing hook bug (not fixed here):** `.claude/settings.local.json` uses `%CLAUDE_PROJECT_DIR%`, which the hook
  shell does not expand — the Rider provenance hook fails with a "blocking error" on every `Edit`/`Write`. It belongs
  to the `settings.local.json` cleanup task named in the issue's out-of-scope list.
- **Not verifiable on the host:** the hook in a Linux/cloud session.
- **Tests deliberately omitted:** the hook is one small script; add Pester tests (`tests/` convention, Pester 6) only
  if it starts failing in practice.
