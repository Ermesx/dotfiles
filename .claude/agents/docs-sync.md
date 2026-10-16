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
- `docs/packages.md`, section *Categories* — the glossary. Its ten names are the only valid categories.
- `ReadMe.md` — the current table between the packages markers (source of existing names and purposes).
- `docs/terminal-bindings.md` — the current list between the bindings markers (source of existing action texts).
- `home/dot_profile/PSReadLine_profile.ps1` and `home/dot_profile/psfzf_profile.ps1` — source of truth for bindings.

## 2. Marker contract

You may edit only the text strictly between these lines, and nothing else in any file:

- `ReadMe.md`: `<!-- BEGIN:packages -->` … `<!-- END:packages -->`
- `docs/terminal-bindings.md`: `<!-- BEGIN:bindings -->` … `<!-- END:bindings -->`

Each marker must appear exactly once per file, BEGIN before END. If a marker is missing, duplicated, or out of
order, **stop: edit nothing in that file and report the problem.** Never append a table elsewhere. Never edit
`home/`, `packages.yaml`, the profile files, or any file other than these two. Use `Edit` on the region only.

## 3. Packages region

One Markdown table, header exactly `| Name | Category | Install Type | Purpose |` (keep the existing column
alignment style: pad cells to the widest cell in the column).

- **Rows:** one per id in `packages.windows.wingets`, `packages.windows.modules`, `packages.dotnet_tools`,
  `packages.yazi_plugins`, plus one row for `packages.windows.wsl` (the distro name). `packages.linux` is out of scope.
- **Install Type:** `App` (wingets), `Module`, `Tool` (dotnet_tools), `Yazi plugin`, `WSL distro`.
- **Category:** the glossary name of the nearest group comment above the id (or above the `wsl` key). An id whose
  group is not in the glossary, or that has no group comment, is **left out of the table and listed under
  "Reported"** — do not guess a category.
- **Order:** glossary order of the category (shell, fzf, git, dotnet, node, containers, chezmoi, editors, browsers,
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
  by `-GitKeyBindings`, and the PSFzf bindings of `-TabExpansion`.
- **Source:** `default` — the chord/function is a PSReadLine default for `-EditMode Windows` (a profile line that
  re-declares the same function on the same chord is still `default`); `changed` — the chord has a default
  function and the profile binds something else; `added` — the chord has no default.
- **Seed defaults** (shown even though the profile does not set them): `Ctrl+]` GotoBrace, `Ctrl+h`
  BackwardDeleteChar, `Alt+.` YankLastArg, `Alt+a` SelectCommandArgument, `Ctrl+l` ClearScreen, `Ctrl+z` Undo,
  `Ctrl+y` Redo, `F7` History. Do not add others and do not remove these unless verification (below) shows one is
  not a default in Windows mode — then drop it and report it.
- **Action text:** one plain-language sentence of what the key does for the user. `-BriefDescription` and
  `-Function` names are input, not the text. If the shortcut already has a row, keep its Action cell verbatim
  unless the action itself changed (different function or purpose).
- **Verification (do not rely on memory):** fetch the PSReadLine key-handler documentation
  (https://learn.microsoft.com/powershell/module/psreadline/about/about_psreadline_functions) to confirm each
  default and its function, and the PSFzf README (https://github.com/kelleyma49/PSFzf) to confirm each PSFzf chord
  and every `-GitKeyBindings` chord. A binding you cannot verify is left out and listed under "Reported".
- **Order:** within a section by shortcut as listed in the sources: profile file order, then PSFzf, then seed defaults.

## 5. Idempotence

If nothing in the sources changed since the last run, the regions must come out **byte-identical**: same rows,
same order, same text. Prefer keeping an existing cell over rewriting it. Do not run for cosmetic reasons.

## 6. Final message

Short, in English: which files you changed; per document the rows added / removed / unchanged; then a
**Reported** list with unknown or missing groups, unverifiable bindings, dropped seed defaults, and marker
problems (or "Reported: none").
