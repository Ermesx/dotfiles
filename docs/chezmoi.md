# chezmoi in this repo

Traps and rules for the chezmoi source in `home/`. Commands are in the root `AGENTS.md`.

## Script names and order

- The phase attribute needs an **underscore** (`before_`, `after_`). With a dash (`run_once_after-foo.ps1`) the
  script has no phase and runs during file application, in lexical order with the files. A correctly parsed name
  comes back from `chezmoi --source . managed --include=scripts` without its prefixes.
- Scripts run in lexical order within a phase, so numeric prefixes (`00-`, `01-`) are load-bearing: one script may
  install what the next one needs.
- `run_onchange_` scripts rerun when their rendered content changes. A script that inlines rendered data (the DSC
  apply script inlines the DSC document) reruns whenever that data changes.

## Templates and scripts

- Pass strings into PowerShell with `| squote`.
- Branch on `.chezmoi.os` (`"windows"` / `"linux"`) inside templates; exclude whole files per OS in the
  `.chezmoiignore` files.
- `env "VAGRANT"` gates test-only behavior in templates.
- `.ps1` scripts run through `pwsh -NoLogo -NoProfile` (`[interpreters.ps1]` in `home/.chezmoi.toml.tmpl`), so they
  cannot rely on the PowerShell profile.

## Encryption

- Encryption is `age`. The identity is `~/.config/chezmoi/key.txt`, itself decrypted on first apply from an `.age`
  file in `home/` with a passphrase. The recipient is in `home/.chezmoi.toml.tmpl`.
- Add or change encrypted files only with `chezmoi add --encrypt <target>` or `chezmoi edit <target>`.

## Claude Code (`~/.claude`)

- `~/.claude` is an ordinary target under `home/dot_claude/`: plain files, no `readonly_` (Claude Code writes them),
  no `.tmpl` unless a real per-OS difference appears (`re-add` skips templates). Windows only for now (#12).
- **Allowlist, not denylist.** `home/.chezmoiignore` ignores `.claude/*` and un-ignores the standard config files
  and directories with `!` entries. A state file missed by a denylist would be committed to a public repo
  (irreversible history); a config file missed by an allowlist is only absent. A bare `.claude` entry beats every
  `!` entry, so the whole-directory ignore lives only in the non-Windows branch. Use `.claude/*`, not `.claude/**`.
- `skills/synced/` (mirror of the claude.ai account skills) and `~/.claude.json` (MCP, OAuth, caches) are not
  managed. `hooks/` is not on the list yet: add `!.claude/hooks` with the first hook script.
- A new standard file (for example `rules/x.md`) shows in `chezmoi unmanaged`; add it with `chezmoi add`.
- Loop after the app rewrites a file: `chezmoi status` → `chezmoi diff` → `chezmoi re-add` → commit on a branch off
  `develop` → push → `chezmoi update` elsewhere. Run `status` / `re-add` before `update`: the "has changed since
  chezmoi last wrote it" prompt is interactive only, `--force` or a non-interactive run overwrites the edit.
- Secrets never go into `settings.json` `env`: use environment variables set from `.encrypted-data.toml.age` in a
  profile template, or `apiKeyHelper`. Hook scripts read secrets from env; otherwise `encrypted_`.
- Anything identifying or work/client specific: `chezmoi add --encrypt` before the first commit (stored as
  `encrypted_*.age`; `status`, `diff` and `re-add` keep working). File names are not encrypted, so use neutral
  names; encrypt every file of a sensitive skill. Encrypted files cannot be merged by git: use `chezmoi merge`.
- **Considered and deferred:** a plain `CLAUDE.md` plus an encrypted `CLAUDE.private.md` imported with
  `@~/.claude/CLAUDE.private.md` (user-scope imports load without a trust dialog). Deferred: nothing to protect when
  decided, and it costs an extra mechanism and unreadable diffs. Revisit when the first non-public content appears.
- Spec: [`specs/claude-config.md`](specs/claude-config.md).
