# Claude Code Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install Claude Code through `packages.yaml` and manage the allowlisted part of `~/.claude` with chezmoi on Windows.

**Architecture:** `~/.claude` is an ordinary chezmoi target under `home/dot_claude/`. `.chezmoiignore` ignores
`.claude/*` and un-ignores an allowlist on Windows; the whole `.claude` is ignored on other OSes. The install entry
goes into `packages.yaml` under a new category `ai`. Rules and the deferred private-`CLAUDE.md` decision are
documentation only.

**Tech Stack:** chezmoi 2.73.1, `.chezmoiignore` templates, DSC v3 via `packages.yaml`, Markdown.

**Spec:** [`docs/specs/claude-config.md`](claude-config.md) (R1–R10, D1–D5)

## Global Constraints

- Branch `feat/19-claude-config` off `develop`. Conventional Commits with a scope; the last commit carries
  `Fixes #19`. Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Commit only when the
  user asks.
- Run chezmoi with `--source .` from the repo root. Never run `chezmoi apply` or `install.ps1` on the host.
  `managed`, `status`, `diff`, `unmanaged`, `add` (writes only into this working copy) are allowed.
- Line endings: `*.md`, `*.yaml`, `*.json` are **LF**; copy `~/.claude` files byte-identical.
- Allowlist entries, exact: `CLAUDE.md`, `settings.json`, `keybindings.json`, `themes`, `rules`, `commands`,
  `agents`, `output-styles`, `workflows`, `skills`; plus `.claude/skills/synced` ignored.
- Ignore patterns use `.claude/*` (not `.claude/**`); a bare `.claude` appears **only** in the non-Windows branch.
- No plaintext secrets; do not touch `*.age` / `encrypted_*`. No version pin or update mechanism for Claude Code.
- Docs, identifiers and commit messages are English.

## Review Focus

1. **Bare `.claude` beats `!` entries** — a `.claude` line outside the `else` branch silently empties the allowlist.
   Owned by Task 2, Step 3 (managed count) and Step 4 (linux render).
2. **New file in an allowlisted dir** (`rules/new.md`) must appear in `unmanaged`. Owned by Task 2, Step 3.
3. **State and claude.ai mirror never addable** — `skills/synced/*`, `.last-cleanup`, `projects/*`. Owned by Task 2,
   Step 3.
4. **Non-Windows render** produces no `.claude` managed path. Owned by Task 2, Step 4.
5. **Secrets in the two copied files** (`env`, marketplace URLs with tokens). Owned by Task 3, Step 4.

---

### Task 1: Install entry and `ai` category

**Files:**
- Modify: `home/.chezmoidata/packages.yaml` (group `# ai` in `windows.wingets`, after the last existing group)
- Modify: `docs/packages.md` (*Categories* table)
- Modify (via agent): `ReadMe.md` package table

**Interfaces:**
- Produces: category name `ai` (used by the YAML comment and the ReadMe *Category* column).

- [ ] **Step 1: Create the branch** — `git switch develop; git switch -c feat/19-claude-config`. `AGENTS.md` already
  has an uncommitted edit; it stays in the working tree and goes into the first commit.
- [ ] **Step 2: Add `Anthropic.ClaudeCode` under a `# ai` comment group** in `windows.wingets`, following the
  surrounding group/blank-line style. No other list changes.
- [ ] **Step 2a: Add `Gitleaks.Gitleaks` to the existing `# git` group** in `windows.wingets` (side effect, spec
  D5; no pin, no other change).
- [ ] **Step 3: Add the row `ai` to the *Categories* table** in `docs/packages.md`:
  `| \`ai\` | AI coding assistants and their CLIs |`, placed after `python`.
- [ ] **Step 4: Verify the DSC document contains the package.**
  Run: `Get-Content -Raw home/.chezmoitemplates/config.dsc.yaml.tmpl | chezmoi --source . execute-template | Select-String 'Anthropic.ClaudeCode|Gitleaks.Gitleaks'`
  Expected: two matches, no `version` key next to either.
- [ ] **Step 5: Run the `docs-sync` agent** (the PostToolUse hook reminds you). Expected: two new ReadMe rows
  (Claude Code `ai`, Gitleaks `git`, both `App`); no other diff in `ReadMe.md`.
- [ ] **Step 6: Commit** — `feat(packages): install Claude Code and Gitleaks (#19)` including `AGENTS.md`.

### Task 2: Ignore rules (allowlist)

**Files:**
- Modify: `home/.chezmoiignore`

**Interfaces:**
- Consumes: nothing.
- Produces: a Windows `.claude` allowlist that Task 3's `chezmoi add` relies on.

- [ ] **Step 1: Edit `home/.chezmoiignore`.** Windows branch: append `.claude/*`, then one `!.claude/<entry>` per
  allowlist entry (Global Constraints order), then `.claude/skills/synced`. `else` branch: append `.claude`.
  Existing lines stay as they are, including the trailing `{{- end -}}`.
- [ ] **Step 2: Run Task 3, Step 1 now** (add the two files) so `managed` has content to check; Task 3 then
  continues from Step 2. Commit both together in Task 2's commit.
- [ ] **Step 3: Verify allowlist behaviour on Windows.**
  Run: `chezmoi --source . managed | Select-String '^\.claude'`
  Expected: `.claude`, `.claude/CLAUDE.md`, `.claude/settings.json` and nothing else.
  Run: `chezmoi --source . unmanaged --path-style=relative | Select-String '^\.claude/'`
  Expected: no `projects`, `state`, `plans`, `telemetry`, `chrome`, `ide`, `daemon*`, `skills/synced`,
  `.last-cleanup`, cache files.
  Run: `chezmoi --source . add $HOME/.claude/skills/synced/manifest.json` (and `$HOME/.claude/.last-cleanup`)
  Expected: `warning: ignoring …`, nothing added.
  Create `$HOME/.claude/rules/_probe.md`, run `unmanaged` again, expect `.claude/rules/_probe.md` listed, then
  delete the probe file.
- [ ] **Step 4: Verify the non-Windows branch.** Copy the rendered file with the OS swapped:
  `(Get-Content -Raw home/.chezmoiignore) -replace '"windows"','"linux"'` into a temp source copy under
  `$env:TEMP` (never into the repo), run `chezmoi --source <tmp> --destination <tmp-dst> --config <empty.toml> managed`.
  Expected: no `.claude` line.
- [ ] **Step 5: Commit** — `feat(chezmoi): allowlist .claude, ignore it off Windows (#19)`.

### Task 3: Managed files and secret scan

**Files:**
- Create: `home/dot_claude/CLAUDE.md`, `home/dot_claude/settings.json`

**Interfaces:**
- Consumes: Task 2 allowlist.
- Produces: tracked `.claude/CLAUDE.md` and `.claude/settings.json` targets.

- [ ] **Step 1: Add the two files** (executed during Task 2, Step 2) — `chezmoi --source . add $HOME/.claude/CLAUDE.md $HOME/.claude/settings.json`.
  Expected: `home/dot_claude/CLAUDE.md` and `home/dot_claude/settings.json`, no `readonly_`, no `.tmpl`.
- [ ] **Step 2: Verify identity and LF.**
  Run: `chezmoi --source . status; chezmoi --source . diff`
  Expected: both empty.
  Run: `(Get-Content -Raw home/dot_claude/settings.json) -match "`r"`
  Expected: `False` (same for `CLAUDE.md`).
- [ ] **Step 3: Verify the app-edit loop on a copy** — in a scratch source/destination (not the host), edit the
  destination `settings.json`, expect ` M` in `status`, `re-add` then clean `status`. Already shown by the spike;
  repeat only if the chezmoi version changed.
- [ ] **Step 4: Secret scan of `home/dot_claude/`.** If `gitleaks` is on `PATH`: `gitleaks detect --no-git --source home/dot_claude`
  (it is declared in Task 1 but installed on this host only by a later apply or `winget install Gitleaks.Gitleaks`;
  ask before installing). Otherwise: `Select-String -Path home/dot_claude/* -Pattern 'sk-|ghp_|AKIA|Bearer |api[_-]?key|token' -CaseSensitive:$false`.
  Expected: no findings (or only the words in prose that are not credentials; list them in the PR description).
  Check `enabledPlugins` / `extraKnownMarketplaces` URLs carry no credentials.
- [ ] **Step 5: Commit** — `feat(chezmoi): manage Claude Code CLAUDE.md and settings.json (#19)`.

### Task 4: Documentation and closing

**Files:**
- Modify: `docs/chezmoi.md` (new section *Claude Code (`~/.claude`)* after *Encryption*)
- Modify: `docs/architecture.md` (*Capabilities* row)
- Modify: `ReadMe.md` (*Daily use* row)
- Modify: `docs/specs/claude-config.md` (Status → Implemented)

**Interfaces:**
- Consumes: Tasks 1–3 (paths and names).

- [ ] **Step 1: Write the `docs/chezmoi.md` section** with the content listed under spec R8, in the file's existing
  bullet style. Include the "Considered and deferred" paragraph verbatim in substance.
- [ ] **Step 2: Add the `docs/architecture.md` row** (R9): capability *Claude Code configuration*, start from
  `home/dot_claude/` and the `.claude` entries in `home/.chezmoiignore`.
- [ ] **Step 3: Add the `ReadMe.md` *Daily use* row** (R10), after the `chezmoi re-add` row:
  goal *Pick up Claude Code settings changed by the app*, command `chezmoi status`, then `chezmoi re-add`, then commit.
- [ ] **Step 4: Final verification.**
  Run: `chezmoi --source . managed | Select-String '^\.claude'` → exactly the three lines from Task 2.
  Run: `Get-Content -Raw home/.chezmoitemplates/config.dsc.yaml.tmpl | chezmoi --source . execute-template | Select-String Anthropic.ClaudeCode` → one match.
  Re-run the Task 3, Step 4 scan over the whole branch diff: `git diff develop --stat` shows only the files in this plan.
- [ ] **Step 5: Set the spec's Status to Implemented, commit** — `docs(chezmoi): document Claude Code config (Fixes #19)`.
