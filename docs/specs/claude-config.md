# Spec: Manage Claude Code configuration (`~/.claude`) with chezmoi

Issue: [#19](https://github.com/Ermesx/dotfiles/issues/19) · Status: Implemented · Date: 2026-10-18 ·
Plan: [`claude-config.plan.md`](claude-config.plan.md)

## Problem

Claude Code is installed on this machine, but nothing under `~/.claude` is managed by chezmoi. A fresh
`install.ps1` gives a bare Claude Code: no tool entry in `packages.yaml`, no global instructions, no settings. The
goal is to install the tool first and then lay the ready-made configuration on top, like every other tool in this
repo.

## Decisions (from the issue)

- Windows only. Linux is developed later (#12); `home/dot_claude/` must not be applied there until it is designed.
- `~/.claude` is an **ordinary chezmoi target**: plain files in `home/dot_claude/`, no `readonly_` (Claude Code
  writes them), no `.tmpl` unless a real per-OS difference appears (`re-add` skips templates).
- Changes made by the app go back to the repo through the normal loop: `chezmoi status` → `diff` → `re-add` →
  commit on a branch off `develop` → push → `chezmoi update` elsewhere. Always `status` / `re-add` before `update`:
  the "has changed since chezmoi last wrote it" prompt is interactive only; `--force` or a non-interactive run
  overwrites the edit.
- **Allowlist**, not denylist. A state file missed by a denylist is committed to a public repo (irreversible
  history); a config file missed by an allowlist is only absent.
- `skills/synced/` is not managed: it mirrors the claude.ai account skills, is recreated on login, and carries
  third-party licenses. `~/.claude.json` (MCP, OAuth, caches) is not managed.
- Install: `Anthropic.ClaudeCode` in `packages.yaml`, new category `ai`, no version pin. Updating installed
  software is winget's job (`Update-Apps`), not chezmoi's (see `AGENTS.md`).
- Sensitive content rules (below). Private `CLAUDE.md` split is **considered and deferred**.
- Out of scope: testing chezmoi or Claude Code behaviour (plugin install on first start, `/context` checks),
  `Check-Updates` reporting `chezmoi status`, Linux, MCP configuration, `modify_` scripts (escape hatch only).
- No ADR: this is not an architecture decision, the reasoning lives here and in `docs/chezmoi.md`.

## Spike result (chezmoi 2.73.1, 2026-10-18)

Run on a scratch source and destination, nothing applied to the host. Claims from the issue (made on 2.65) held,
except where marked.

| Check | Result |
|---|---|
| `.claude/*` then `!.claude/<path>` allowlist in `.chezmoiignore` | **Works.** `managed` lists only allowlisted paths; `skills/synced` (ignored after `!.claude/skills`) and `.last-cleanup` are ignored. |
| `chezmoi add` of an ignored path | Refused with `warning: ignoring …`. |
| `chezmoi unmanaged` | Does not list ignored state paths; lists a new file in an allowlisted dir (`rules/new.md`). |
| `status` / `re-add` after an app-style edit | `status` shows ` M`; `re-add` copies it into the source; `status` is then clean. |
| **A plain `.claude` entry in the same file** | **Wins over every `!` entry**, regardless of order. The Linux whole-directory ignore must therefore sit in its own `else` branch, never next to the allowlist. |
| `.claude/**` instead of `.claude/*` | Also excludes allowlisted files. Use `.claude/*`. |

Not covered by the spike: `chezmoi add` into the real source (spike destination was under a protected path); done
in the plan's Task 3 against the real files.

## Decisions added by this spec

| # | Decision | Why |
|---|---|---|
| D1 | **`.chezmoiignore` layout:** the Windows branch gets the allowlist (`.claude/*`, `!` entries, `.claude/skills/synced`); the `else` branch gets `.claude`. Nothing `.claude`-related outside the `if`. | Spike: a bare `.claude` beats `!`. The issue put "ignore entries in the non-Windows branch" — still true for `.claude`, but the allowlist must live in the Windows branch. |
| D2 | **Allowlist entries** (exact): `CLAUDE.md`, `settings.json`, `keybindings.json`, `themes`, `rules`, `commands`, `agents`, `output-styles`, `workflows`, `skills`. Entries for directories that do not exist yet are kept. | A new file then shows in `chezmoi unmanaged` and is added with one `chezmoi add`. |
| D3 | **`hooks/` is not on the allowlist** (my call). | Not in the documented standard set, no hook scripts exist in `~/.claude` today. Add the entry together with the first hook script. |
| D4 | **`skills/<name>/` hand-written only.** Only `synced/` is excluded by name; a skill dropped there by another tool is caught in review of `chezmoi unmanaged`. | Whether skill-creator or claude-reflect write to `~/.claude/skills/` is unverified; do not pre-empt it. |
| D5 | **Secret scan** before the first push: `gitleaks detect`. `Gitleaks.Gitleaks` (winget ID verified 2026-10-18) is added to `packages.yaml` in this change as a side effect, outside the scope of #19 (too small for its own issue). Category `git` (my call: repo inspection). Until the package is installed on this machine, fall back to a regex scan of `home/dot_claude/` for `sk-`, `ghp_`, `AKIA`, `Bearer `, `api[_-]?key`, `token`. | Public repo. |

## Requirements

**Install**
- **R1** `home/.chezmoidata/packages.yaml` lists `Anthropic.ClaudeCode` under `windows.wingets` in a `# ai` group
  (no pin).
- **R1a** (side effect, D5) `Gitleaks.Gitleaks` under `windows.wingets`, in the existing `# git` group, no pin.
- **R2** `docs/packages.md` *Categories* table gains `ai` (AI coding assistants and their CLIs). The ReadMe table
  rows (Claude Code: Category `ai`; Gitleaks: Category `git`; both Install Type `App`) are generated by the
  `docs-sync` agent.

**Ignore rules** (`home/.chezmoiignore`)
- **R3** Windows branch: `.claude/*`, then `!.claude/<entry>` for each D2 entry, then `.claude/skills/synced`.
- **R4** Non-Windows branch: `.claude`.
- **R5** Existing entries of both branches are unchanged.

**Managed files** (`home/dot_claude/`)
- **R6** `CLAUDE.md` and `settings.json` from the current `~/.claude`, byte-identical (LF). No `.tmpl`, no
  `readonly_`. Other D2 entries are not created.
- **R7** After the change, on Windows: `chezmoi --source . managed` lists only `.claude` plus the two files;
  `chezmoi --source . status` and `diff` are empty; `chezmoi --source . unmanaged ~/.claude` shows no state
  directory (`state`, `plans`, `telemetry`, `chrome`, `ide`, `projects`, `daemon*`, caches, `.last-cleanup`).
  Rendering the ignore file with `.chezmoi.os` = `linux` yields no `.claude` managed path.

**Sensitive content** (documented, no code)
- **R8** `docs/chezmoi.md` gets a **tool-agnostic** section *Config that the app rewrites* (the rules below, stated
  generally; Claude-specific details stay in this spec). It states:
  - the allowlist rule and D1–D4, and that a new standard file is added with `chezmoi add`;
  - the daily loop (`status` → `diff` → `re-add`) and why `re-add` precedes `update`;
  - secrets never go into `settings.json` `env`: use environment variables set from `.encrypted-data.toml.age` in
    a profile template, or `apiKeyHelper`;
  - anything identifying or work/client specific: `chezmoi add --encrypt` before the first commit (stored as
    `encrypted_*.age`; `status`, `diff`, `re-add` keep working). File names are not encrypted, so use neutral
    names; encrypt every file of a sensitive skill. Encrypted files cannot be merged by git: `chezmoi merge`;
  - hook scripts read secrets from env, otherwise `encrypted_`; MCP servers (`~/.claude.json`) are not managed;
  - **Considered and deferred:** plain `CLAUDE.md` plus encrypted `CLAUDE.private.md` imported with
    `@~/.claude/CLAUDE.private.md` (user-scope imports load without a trust dialog). Deferred: nothing to protect
    today, costs an extra mechanism and unreadable diffs. Revisit when the first non-public content appears.
- **R9** `docs/architecture.md` *Capabilities* gets a row for Claude Code configuration pointing at
  `home/dot_claude/` and the `.claude` entries in `home/.chezmoiignore`.
- **R10** `ReadMe.md` *Daily use* gets one row for the Claude flow: pick up an app edit with `chezmoi re-add`, then
  commit; new standard file with `chezmoi add`.

## Risks and counter-arguments

| Risk | Mitigation / what would change the decision |
|---|---|
| Claude Code rewrites `settings.json` with machine-local noise (paths, per-machine toggles) | Then `modify_` script for that file. Not before there is evidence. |
| `enabledPlugins` / `extraKnownMarketplaces` pull third-party marketplaces onto every new machine | They are file content; this is the intended "ready-made settings". Review the diff before commit. |
| An allowlisted directory later receives tool-generated content (D4) | `chezmoi unmanaged` review; add a name to the ignore block. |
| Allowlist is silent about new Claude Code config files | Intended (absent, not leaked). A new standard file requires a one-line allowlist addition. |

## Acceptance criteria

- [ ] R1–R10 implemented as written.
- [ ] R7 commands run and their output matches (recorded in the PR description).
- [ ] D5 scan clean before the first push.
- [ ] `docs-sync` run after the `packages.yaml` change; ReadMe table contains the `ai` row.
- [ ] Spec status set to Implemented; the last commit carries `Fixes #19`.
