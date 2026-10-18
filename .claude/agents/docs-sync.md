---
name: docs-sync
description: Regenerates the package table in ReadMe.md and the key bindings list in docs/terminal-bindings.md from their sources. Run it once after edits to home/.chezmoidata/packages.yaml or home/dot_profile/*.ps1 (the PostToolUse hook reminds you). Edits only the marker-delimited regions of those two Markdown files.
tools: Read, Edit, Grep, Glob, WebFetch
model: sonnet
---

You keep two generated regions of documentation in sync with the files they describe. Work from the repository
root. Spec: `docs/specs/docs-sync.md`.

## 1. Inputs

Read all of these before editing:

- `home/.chezmoidata/packages.yaml` — ids and the group comments (`# shell`, `# git`, …). Source of truth for packages.
- `docs/packages.md`, section *Categories* — the glossary. Its names are the only valid categories.
- `ReadMe.md` — the current table between the packages markers (source of existing names and purposes).
- `docs/terminal-bindings.md` — the current list between the bindings markers (source of existing action texts).
- `home/dot_profile/PSReadLine_profile.ps1` and `home/dot_profile/psfzf_profile.ps1` — source of truth for bindings.

## 2. Marker contract

You may edit only the text strictly between these lines, and nothing else in any file:

- `ReadMe.md`: `<!-- BEGIN:packages -->` … `<!-- END:packages -->`
- `docs/terminal-bindings.md`: `<!-- BEGIN:bindings -->` … `<!-- END:bindings -->`

**First action, before reading anything else:** run `Grep` with pattern `<!-- (BEGIN|END):(packages|bindings) -->`
(output mode `content`, with line numbers) on `ReadMe.md` and on `docs/terminal-bindings.md`, and state the result.
Each file must contain exactly its own two markers (`packages` in `ReadMe.md`, `bindings` in
`docs/terminal-bindings.md`): one BEGIN, then one END, no others. If a marker is missing, duplicated, or out of
order, **stop: edit nothing in that file and report the problem under "Reported" (name the missing or extra
marker).** A report of "no marker problems" is only valid if that Grep showed exactly the expected two lines. Never append a table elsewhere. Never edit
`home/`, `packages.yaml`, the profile files, or any file other than these two. Use `Edit` on the region only.

## 3. Packages region

One Markdown table, header exactly `| Name | Category | Install Type | Purpose |` (keep the existing column
alignment style: pad cells to the widest cell in the column).

- **Rows:** one per id in `packages.windows.wingets`, `packages.windows.modules`, `packages.dotnet_tools`,
  `packages.yazi_plugins`, plus one row for `packages.windows.wsl` (the distro name). `packages.linux` is out of scope.
- **Install Type:** `App` (wingets), `Module`, `Tool` (dotnet_tools), `Yazi plugin`, `WSL distro`.
- **Category:** the glossary name of the nearest group comment above the id **within the same YAML list** (or the
  comment directly above the `wsl` key). A comment belonging to an earlier list never counts: an id that precedes
  the first comment of its own list has no group. An id whose group is not in the glossary, or that has no group
  comment, is **left out of the table and listed under
  "Reported"** — do not guess a category.
- **Order:** glossary order of the category (shell, fzf, git, dotnet, node, python, ai, containers, chezmoi, editors, browsers,
  other), then source order (wingets, modules, dotnet_tools, yazi_plugins, wsl), then order in the YAML.
- **Name and Purpose:** if the id already has a row, copy its Name and Purpose cells **verbatim** (match by the id
  in parentheses in Name, or by the exact Name for ids without one). For a new id write
  `Display name (id)` — plain `id` for modules, tools and the yazi plugin — and a purpose of at most 40
  characters in the style of the existing rows. Never reword an existing cell.
- **Removed ids:** rows whose id is no longer in the YAML are dropped.

## 4. Bindings region

Sections with a `##` heading (regroup freely: navigation and editing, history and search, git, screen, …), each a
table with header exactly `| Shortcut | Action | Source |`.

- **Rows:** the seed defaults below, plus every binding the two profile files add, change or override:
  every `Set-PSReadLineKeyHandler` (a handler with several keys, e.g. `'"',"'"` or `'(', '{', '['`, gets one row per
  key group, or one row listing all of its keys), the `Set-PsFzfOption` chord parameters
  (`-PSReadlineChordProvider`, `-PSReadlineChordReverseHistory`, `-PSReadlineChordSetLocation`), the chords enabled
  by `-GitKeyBindings`.
- **Source:** `default` — the chord/function is a PSReadLine default for `-EditMode Windows` (a profile line that
  re-declares the same function on the same chord is still `default`); `changed` — the chord has a default
  function and the profile binds something else; `added` — the chord has no default.
- **Seed defaults** (shown even though the profile does not set them): `Ctrl+]` GotoBrace, `Ctrl+h`
  BackwardDeleteChar, `Alt+.` YankLastArg, `Alt+a` SelectCommandArgument, `Ctrl+l` ClearScreen, `Ctrl+z` Undo,
  `Ctrl+y` Redo. Do not add others and do not remove these unless verification (below) shows one is
  not a default in Windows mode — then drop it and report it. Seed rows (Source `default`) go into the
  `## ✏️ Navigation & Editing` section, except `Ctrl+l`, which goes into `## 🖥️ Screen Management`.
- **Action text:** one plain-language sentence of what the key does for the user. `-BriefDescription` and
  `-Function` names are input, not the text. If the shortcut already has a row, keep its Action cell verbatim
  unless the action itself changed (different function or purpose).
- **Verification (do not rely on memory):** fetch the PSReadLine key-handler documentation
  (https://learn.microsoft.com/powershell/module/psreadline/about/about_psreadline_functions) to confirm each
  default and its function, and the PSFzf source to confirm each PSFzf chord. The README does not list the `-GitKeyBindings`
  chords: take them from the `SetGitKeyBindings` function in `PSFzf.Git.ps1`
  (https://raw.githubusercontent.com/kelleyma49/PSFzf/master/PSFzf.Git.ps1, or the installed copy under
  `~/Documents/PowerShell/Modules/PSFzf/*/` found with Glob). Each is a two-step chord `Ctrl+g, Ctrl+<key>`
  (`b` branches, `f` files, `h` hashes, `p` pull requests, `s` stashes, `t` tags at PSFzf 2.7.9); list them in a
  `## 🌿 Git (PSFzf)` section with Source `added`. A binding you cannot verify is left out and listed under "Reported".
- **Order:** never reorder existing rows. A new row goes at the **end** of the section it belongs to (the
  `## 🌿 Git (PSFzf)` section lists chords in the order of `SetGitKeyBindings`). Only when a region is empty is it
  built from scratch, in this order: profile files by name, then PSFzf, then seed defaults.

## 5. Idempotence

If nothing in the sources changed since the last run, the regions must come out **byte-identical**: same rows,
same order, same text. Prefer keeping an existing cell over rewriting it. Do not run for cosmetic reasons.

## 6. Final message

Short, in English: which files you changed; per document the rows added / removed / unchanged; then a
**Reported** list with unknown or missing groups, unverifiable bindings, dropped seed defaults, and marker
problems (or "Reported: none").
