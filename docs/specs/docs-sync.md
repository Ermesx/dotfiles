# Spec: Agent and hook keep the README package table and key bindings list in sync with source

Issue: [#17](https://github.com/Ermesx/dotfiles/issues/17) · Status: Implemented · Date: 2026-10-16 ·
Plan: [`docs-sync.plan.md`](docs-sync.plan.md)

## Problem

Two hand-maintained documents drift from the source they describe, and nothing detects it:

| Doc | Source of truth | Drift today (verified 2026-10-16) |
|---|---|---|
| `ReadMe.md` → *Installed Applications & Modules* | `home/.chezmoidata/packages.yaml` | Lists .NET SDK 9 and `GnuWin32.File` (both gone). Misses jq, GitHub CLI, Node.js, Vagrant, Scalar, refitter, the yazi plugin, the WSL distro. Category names differ from the YAML group comments (`docker` vs `containers`; yazi `other` vs `shell`). `modules`, `dotnet_tools`, `yazi_plugins`, `wsl` have no group comments. |
| `docs/terminal-bindings.md` | `home/dot_profile/PSReadLine_profile.ps1`, `home/dot_profile/psfzf_profile.ps1` + PSReadLine defaults for `-EditMode Windows` | Wrong chords (`Alt+c`, `Ctrl+r`, `Ctrl+h`, `Ctrl+f`, `Ctrl+p`), `Ctrl+h` twice, `Ctrl+d` bound nowhere, and every binding added in code is missing. |

`docs/packages.md` calls the table "a manual mirror … updated by hand". That is the process that failed.

The one-time correction of both documents is the **first run** of the mechanism below, not a separate manual edit.

## Decisions (from the issue, unchanged)

- `packages.yaml` stays a plain list of ids. The only category information is the group comments.
- One category glossary, defined once in `docs/packages.md`, used by the YAML group comments and the README
  *Category* column: `shell`, `fzf`, `git`, `dotnet`, `node`, `containers`, `chezmoi`, `editors`, `browsers`, `other`.
- Display name and purpose live only in the README table; the agent keeps existing values and writes new ones.
- Generation is done by a Claude Code agent (judgement needed: which defaults to show, how to word them), not a script.
- The trigger is a `PostToolUse` hook on `Edit|Write`, path match only.

## Decisions added by this spec

These close gaps the issue leaves open. Each is cheap to reverse; flag any you disagree with.

| # | Decision | Why |
|---|---|---|
| D1 | **Category of the unlabelled lists:** `dotnet_tools` → `dotnet`; `yazi_plugins` → `shell`; `wsl` → `other`; `modules` get per-category comment groups like `wingets` (`shell`: WinGet.Client, Terminal-Icons · `fzf`: PSfzf · `git`: posh-git · `containers`: DockerCompletion · `other`: powershell-yaml, Pester). | Matches the README's current categories and the yazi precedent in the YAML. No new glossary names. |
| D2 | **Linux section:** its `# docker` comment is renamed `# containers` (comment only). `packages.linux` is otherwise not documented in the table. | "Group comments use only glossary names" has to hold for the whole file; Linux scope itself stays with #12. |
| D3 | **Row order** is deterministic: glossary category order, then source order (`wingets`, `modules`, `dotnet_tools`, `yazi_plugins`, `wsl`), then YAML order. | An LLM-generated file is only reviewable if a no-change rerun produces no diff. |
| D4 | **Idempotence is a requirement:** a rerun with unchanged sources must produce a byte-identical file. Existing *Name* and *Purpose* cells are copied verbatim, never reworded. | Same reason. Drives most of the agent prompt. |
| D5 | **Curated PSReadLine defaults are a fixed seed list inside the agent file**, not re-chosen on every run. The agent verifies each against the PSReadLine docs and drops any that is not a default in Windows mode. | Without a seed the "which defaults" judgement changes run to run. |
| D6 | **A profile line that re-declares a default** (same chord, same function) is listed once with source `default`. A chord that is rebound to something else is `changed`; a chord with no default is `added`. | Needed to classify `Ctrl+Spacebar`, `Ctrl+Enter` and similar without guessing. |
| D7 | **The hook only injects `additionalContext`**; it cannot start an agent itself. Compliance is the session's job. It is a reminder, not a gate. | Hooks cannot spawn subagents. A missed run is caught by the next run (regions are regenerated from source). |
| D8 | **Hook is a small `python3` script**, `.claude/hooks/docs-sync-trigger.py`, without automated tests. | The repo's existing hook already needs `python3`; `pwsh` is not guaranteed in Linux/cloud sessions. One small script does not justify new test tooling; it is verified by a manual smoke check and the live trigger (A2, A6). Add tests only if it starts failing in practice. Rejected: a `PostToolUse` `if` filter with an inline `echo` — quoting JSON differs between shells and the match logic stays inside settings JSON. |
| D9 | **Trigger paths:** `home/.chezmoidata/packages.yaml` and `home/dot_profile/*.ps1` (literal `.ps1`; `*.ps1.tmpl` does not match). Matching is on the normalised tool path (`\` → `/`), anchored on the repo-relative suffix so it works in worktrees. | Issue wording, made precise. |

## Requirements

**Glossary and YAML**
- **R1** `docs/packages.md` defines the glossary (names above, one line each).
- **R2** Every group comment in `packages.yaml` (all lists, incl. `linux`) uses a glossary name; `modules`,
  `dotnet_tools`, `yazi_plugins`, `wsl` have group comments per D1. No id is added, removed or moved to a different
  list: the rendered DSC document is identical before and after.

**Agent** (`.claude/agents/docs-sync.md`)
- **R3** Rewrites only the regions between `<!-- BEGIN:packages -->`/`<!-- END:packages -->` in `ReadMe.md` and
  `<!-- BEGIN:bindings -->`/`<!-- END:bindings -->` in `docs/terminal-bindings.md`. Edits nothing else, nothing in
  `home/`, never `packages.yaml`.
- **R4** Packages: one row per id in `windows.wingets`, `windows.modules`, `dotnet_tools`, `yazi_plugins`, plus one
  row for `windows.wsl`. Columns unchanged: `Name | Category | Install Type | Purpose`. Install Type ∈ `App`,
  `Module`, `Tool`, `Yazi plugin`, `WSL distro`. Category comes from the group comment. Rows for ids no longer in
  the YAML are dropped. An id under a group not in the glossary (or no group) is **reported in the final message
  and left out of the table**, not guessed.
- **R5** Bindings: columns `Shortcut | Action | Source` (`default` / `changed` / `added`, per D6). Contents: the
  seed defaults (D5) plus every binding the two profile files add, change or override — `Set-PSReadLineKeyHandler`
  (incl. multi-key and paired-char handlers), the `Set-PsFzfOption` chord parameters
  (`-PSReadlineChordProvider`, `-PSReadlineChordReverseHistory`, `-PSReadlineChordSetLocation`), and every chord enabled by `-GitKeyBindings` (read from the PSFzf
  documentation, not memory). *Action* is a short plain-language sentence; `-BriefDescription`/`-Function` are input
  only. Sections inside the region may be regrouped (navigation, history/search, git, …).
- **R6** PSReadLine and PSFzf behaviour is verified against their documentation for the installed versions; a
  binding the agent cannot verify is reported, not listed.
- **R7** Idempotence (D4) and ordering (D3).

**Hook** (`.claude/settings.json`, `.claude/hooks/docs-sync-trigger.py`)
- **R8** `PostToolUse`, matcher `Edit|Write`, runs the script with `python3`. For a matching path (D9) it prints
  `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"…"}}` telling the session to run the
  `docs-sync` agent once its current edits are done. For any other path, malformed input, or a missing
  `file_path`, it prints nothing and exits 0.
- **R9** No network, no `chezmoi`, runs on Windows and Linux. The existing `settings.local.json` hook is untouched
  (hooks from both files merge).

**Docs**
- **R10** `docs/packages.md` no longer says the table is a manual mirror; it says the marked regions are generated by
  the `docs-sync` agent. `docs/architecture.md` and `docs/conventions.md` each mention the agent and the generated
  regions (conventions: *do not hand-edit text between markers; edits are overwritten*).

## Non-goals

Exactly the issue's list: Linux packages (#12); bindings of other tools (Windows Terminal, yazi, PowerToys); a git
`pre-commit` check for edits made outside Claude Code; README link fixes incl. `docs/bindings.md` (#25); removing
the committed `.claude/settings.local.json`. Additionally: no generic "docs sync" framework, no per-package
metadata, no change to the DSC template.

## Acceptance

- [ ] **A1 (R1, R2)** `chezmoi --source . execute-template` of `home/.chezmoitemplates/config.dsc.yaml.tmpl` is
  byte-identical before/after the YAML change; `git diff -U0 home/.chezmoidata/packages.yaml` contains only
  comment and blank lines.
- [ ] **A2 (R8, R9)** Manual smoke check of the script (plan, Task 2 Step 3): matching paths (forward and back
  slashes, worktree) print the JSON; `ReadMe.md`, `packages.yaml.bak`, `check-updates.ps1.tmpl`, empty and invalid
  stdin print nothing; exit code is always 0.
- [ ] **A3 (R3–R7)** First agent run on the current tree: the README table has exactly one row per id (ids and
  categories match the YAML, incl. yazi plugin and WSL distro, no `GnuWin32.File`, no `.NET SDK 9`); the bindings
  list matches the profile files plus the seed defaults; `git diff` outside the markers is empty.
- [ ] **A4 (R7)** Second run with no source change: `git diff` is empty.
- [ ] **A5 (R4)** Mutation check: remove one id from a scratch copy of the YAML → its row disappears; add an id
  under `# unknown` → reported, not added.
- [ ] **A6 (R8)** In a fresh Claude Code session, editing `packages.yaml` or a profile file shows the reminder;
  editing `docs/conventions.md` does not.
- [ ] **A7 (R10)** The three docs are updated as stated.

## Risks and open points

- **AIChat (#21).** `sigoden.AIChat` is still in `packages.yaml`, so by R4 the first run adds a row for it, which
  the issue says should not happen. Recommended: land #21 first. If #17 lands first, the AIChat row appears and #21
  removes it through this same mechanism. No ignore-list is added (YAGNI).
- **The hook is advisory (D7).** The session can ignore it. Accepted: the failure mode is a stale doc until the next
  edit of a source file, which is the status quo minus the cases the hook catches. The git `pre-commit` follow-up is
  the structural fix.
- **LLM output is not deterministic.** D3–D5 constrain it, and A4 tests it, but a model change can still reword
  cells. D4 (copy existing cells verbatim) limits this to new rows.
- **`python3` on Windows** may resolve to the Microsoft Store stub on a fresh host. The existing Rider hook already
  depends on it; the plan verifies it on this host only (3.12.10). If it fails in the VM or on another machine, the
  hook errors non-blocking (Claude shows a hook error) and the doc just doesn't auto-sync.
- **Hook shell syntax (observed 2026-10-16).** On this Windows host hook commands do not run under `cmd.exe`: the
  existing `settings.local.json` hook uses `%CLAUDE_PROJECT_DIR%`, which is not expanded and fails with "can't open
  file …\%CLAUDE_PROJECT_DIR%\.claude\hooks\post-tool-call.py". The new hook therefore uses
  a project-relative path (`python3 .claude/hooks/docs-sync-trigger.py`): the same error shows hooks start in the
  project root, and a relative path needs no variable expansion, so it does not depend on which shell runs it
  (`$CLAUDE_PROJECT_DIR` would be empty under PowerShell, which uses `$env:`). Fixing the existing Rider hook is out of scope (same file as the `settings.local.json`
  cleanup); it is reported in the plan's hand-off. Whether the hook's cwd is the worktree or the main checkout is not
  verified; A6 checks it. The script itself does not depend on it (D9).
  **Correction (observed later):** the cwd assumption was wrong. The hook inherits the session's current directory,
  so after Claude changes directory (e.g. into `home/.chezmoiscripts/windows`) the relative path fails with
  "can't open file …\windows\.claude\hooks\docs-sync-trigger.py". The hook now uses exec form,
  `"command": "python3", "args": ["${CLAUDE_PROJECT_DIR}/.claude/hooks/docs-sync-trigger.py"]`: Claude Code
  substitutes the placeholder itself, so no shell expands anything and spaces in the path need no quoting. Verified
  with `claude -p` 2.1.292: the hook ran from a subdirectory with a space in its path.
- **Hook change needs a session restart** (settings are read at start), so A6 cannot be tested in the session that
  implements it.
