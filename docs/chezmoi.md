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
- Sensitive data never goes into the repo in plain text. Secrets (tokens, keys) stay out of tool config files: pass
  them as environment variables set from `.encrypted-data.toml.age`. Everything else that is private or identifying
  (personal data, work or client specifics) is encrypted with `chezmoi add --encrypt` before its first commit; file
  names stay readable, so use neutral names and encrypt every file of the item. Git cannot merge encrypted files:
  use `chezmoi merge`.
- Run `gitleaks detect` before pushing new config. It finds credentials, not personal content: review those files
  yourself.
