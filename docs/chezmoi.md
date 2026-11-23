# chezmoi in this repo

Traps and rules for the chezmoi source in `home/`. Commands are in the root `AGENTS.md`.

## Script names and order

- The phase attribute needs an **underscore** (`before_`, `after_`). With a dash (`run_once_after-foo.ps1`) the
  script has no phase and runs during file application, in lexical order with the files. A correctly parsed name
  comes back from `chezmoi --source . managed --include=scripts` without its prefixes.
- Scripts run in lexical order within a phase, so numeric prefixes (`00-`, `01-`) are load-bearing: one script may
  install what the next one needs.
- `run_onchange_` scripts rerun when their rendered content changes. A script that inlines rendered data (the Scoop
  install script inlines the rendered app list) reruns whenever that data changes.
- Each script is a separate process started with chezmoi's environment, so environment changes never pass from
  one script to the next. Apps that Scoop exposes through shims (`bin` in the manifest) work at once, because
  `~/scoop/shims` is on `PATH` since `install.ps1`. A script that calls an app which adds its own `PATH` entry or
  variables (`env_add_path`, `env_set`) reads them back from the user registry first; today only
  `03-dotnet-tools` does this, for `dotnet-sdk`.

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
- The git identity and signing key live in `home/dot_config/git/user.gitconfig.tmpl` (decrypted), which
  `.gitconfig` pulls in with `[include]`; `.gitconfig` itself never decrypts. Commits are signed with the SSH key;
  `home/dot_config/git/allowed_signers.tmpl` (decrypted) lists it so git can verify signatures locally.
- With `CI=true` (what GitHub sets; any other value, e.g. a stray `CI=1`, keeps everything managed), the
  `{{ if eq (env "CI") "true" }}` block in `home/.chezmoiignore` drops every target that needs decryption. A
  new decryption point needs an entry there; `tests/static/NoDecryptInCi.Tests.ps1` fails until it has one
  ([testing.md](testing.md)).
- Add or change encrypted files only with `chezmoi add --encrypt <target>` or `chezmoi edit <target>`.
- Sensitive data never goes into the repo in plain text. Secrets (tokens, keys) stay out of tool config files: pass
  them as environment variables set from `.encrypted-data.toml.age`. Everything else that is private or identifying
  (personal data, work or client specifics) is encrypted with `chezmoi add --encrypt` before its first commit; file
  names stay readable, so use neutral names and encrypt every file of the item. Git cannot merge encrypted files:
  use `chezmoi merge`.
- Run `gitleaks detect` before pushing new config. It finds credentials, not personal content: review those files
  yourself.
