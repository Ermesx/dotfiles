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
- The Windows install scripts report through the `StepProgress` module
  (`home/readonly_Documents/PowerShell/Modules/StepProgress/`): one live line locally, one line per item when
  `CI=true`, tool output only for an item that failed, and an item that is already installed is counted, not listed.
  A `before_` script runs before any file is written, so the copy deployed to `~/Documents` does not exist on the
  first apply; the scripts therefore import the module from `$env:CHEZMOI_SOURCE_DIR`. They use that variable, not
  the template variable `.chezmoi.sourceDir`, so the machine path stays out of the rendered script and out of
  chezmoi's change hash. A failed item makes the script exit 1: `chezmoi apply` stops and the next apply retries it.
  The `PackageUpdates` module (`Update-Apps`, `Update-Modules`, `Update-DotnetTools`) uses the same module from the
  deployed copy.

## Templates and scripts

- Pass strings into PowerShell with `| squote`.
- Branch on `.chezmoi.os` (`"windows"` / `"linux"`) inside templates; exclude whole files per OS in the
  `.chezmoiignore` files.
- `env "VAGRANT"` gates test-only behavior in templates.
- The profile selection is stored in the chezmoi config (`profiles`, `picks`, `offered`) and asked only by
  `chezmoi init`. Change it with `chezmoi init --prompt` (stored answers are the defaults); plain `apply` never
  asks. Templates read it through `packages.tmpl`, see [packages.md](packages.md).
- `.chezmoi.toml.tmpl` gets no `.packages` data: it reads profile names and `pick` flags from `packages.yaml` with
  `include`.
- `.ps1` scripts run through `pwsh -NoLogo -NoProfile` (`[interpreters.ps1]` in `home/.chezmoi.toml.tmpl`), so they
  cannot rely on the PowerShell profile.
- `home/.chezmoiversion` sets the minimum chezmoi version (2.60.0, where promptMultichoiceOnce appeared);
  an older chezmoi stops with a clear message instead of a template parse error.

## Encryption

- Encryption is `age`. The identity is `~/.config/chezmoi/key.txt`, itself decrypted on first apply from an `.age`
  file in `home/` with a passphrase. The recipient is in `home/.chezmoi.toml.tmpl`.
- The git identity and signing key live in `home/dot_config/git/user.gitconfig.tmpl` (decrypted), which
  `.gitconfig` pulls in with `[include]`; `.gitconfig` itself never decrypts. Commits are signed with the SSH key;
  `home/dot_config/git/allowed_signers.tmpl` (decrypted) lists it so git can verify signatures locally.
- The work email is not repo data. `chezmoi init` asks for it once on a work machine; an empty answer, an accidental
  Enter included, marks a private machine, where nothing work-related is written. Only a plain address is accepted
  (it is written unescaped into `~/.gitconfig`); anything else fails the init. It is stored only in that
  machine's chezmoi config (`[data.git] work_email`) and read by `home/dot_gitconfig.tmpl`, which then makes it the
  default `user.email` and gives any github.com remote the personal identity back. To change the answer:
  `chezmoi init --prompt`. A non-interactive run (CI, the VM, an unattended install) passes it in
  `DOTFILES_GIT_WORK_EMAIL`; with `DOTFILES_PROFILES` set and no variable the prompt is skipped and the stored value
  is kept.
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
