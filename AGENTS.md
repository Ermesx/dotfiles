# AGENTS.md

Personal dotfiles that set up Windows (fully) and Linux (partially) from one [chezmoi](https://www.chezmoi.io/)
source, with Windows software installed declaratively through DSC v3.

This file is canonical (`CLAUDE.md` only imports it) and deliberately minimal: topic rules live in `docs/`, linked
below. Add a rule here only if it applies to every task.

## Always

- Run chezmoi with `--source .` from the repo root. The local chezmoi config points at `~/.local/share/chezmoi`, a
  separate clone; without the flag you read the installed source, not this working copy.
- Never run `chezmoi apply` or `install.ps1` on the host to test a change — they install software, write to `HKLM`,
  and change services. Use the VM; otherwise ask first.
- Never commit plaintext secrets. Never decrypt `*.age` files into the repo or edit `*.age` / `encrypted_*` files as
  text.
- Known bugs are tracked as GitHub issues (`gh issue list`). Check them before touching related code; reference the
  issue (`Fixes #N`) in the change that fixes it.
- Git: branch off `develop`; Conventional Commits with a scope (`feat(packages): …`); commit only when asked.

## Commands

PowerShell, from the repo root.

| Purpose | Command |
|---|---|
| Every target the source produces (attributes resolved) | `chezmoi --source . managed` |
| Scripts and how their names were parsed | `chezmoi --source . managed --include=scripts` |
| Render a template | `Get-Content -Raw home/<path>.tmpl \| chezmoi --source . execute-template` |
| Preview what apply would change (runs no scripts) | `chezmoi --source . diff` |
| DSC drift, installs nothing | Render `home/.chezmoitemplates/config.dsc.yaml.tmpl` as above, pipe to `dsc config test -f -` |
| Full install test (slow) | `cd tests; vagrant up dotfiles-windows`, then in the VM `C:\vagrant\run-tests.ps1 -BRANCH <branch>` |

## Read before you change

| Touching | Read |
|---|---|
| Anything under `home/` | [`docs/chezmoi.md`](docs/chezmoi.md) |
| Installed software, `packages.yaml`, DSC | [`docs/packages.md`](docs/packages.md) |
| Scripts, PowerShell profile, line endings | [`docs/conventions.md`](docs/conventions.md) |
| `tests/`, the VM, `install.ps1` | [`docs/testing.md`](docs/testing.md) |
| Not sure where a capability lives | [`docs/architecture.md`](docs/architecture.md) |
| A design choice (tool, layout, mechanism) or anything that reverses one | [`docs/adr/`](docs/adr/) — the architecture decision record; don't edit an accepted ADR, add a new one that supersedes it |
| A feature or change that has a spec | [`docs/specs/`](docs/specs/) — specifications: what to build and how it should behave; the ADR records why |
