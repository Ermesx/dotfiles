# Testing

Three layers, from the most to the least frequent. Design and decisions: [`specs/three-layer-testing.md`](specs/three-layer-testing.md).

| Layer | What it proves | Where | When | Command |
|---|---|---|---|---|
| **Static** | Every template renders; no decryption when `CI` is set; `packages.yaml` schema; every Scoop item exists in its bucket; doc links resolve | Host and CI | Every change | `pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; Invoke-Pester tests/static -Output Detailed'` |
| **Unit** | Profile modules and admin scripts, with mocks | Host and CI | Every change to them | See *Unit tests against the working copy* |
| **CI** (`.github/workflows/ci.yml`) | Static + unit, then a real `chezmoi init --apply` on a clean `windows-latest`, then the post-apply tests | GitHub Actions | PRs to `develop`, pushes to `develop` | Runs by itself; `workflow_dispatch` to rerun |
| **VM** | `install.ps1` end to end as a **standard user** (no admin), including decryption | Vagrant VM | Before large changes | See *VM* |

## Static layer

`tests/static/StaticChecks.psm1` holds the checks; each `*.Tests.ps1` runs a check against the repo (expects
nothing) and against a `TestDrive:` fixture with a planted fault (expects it reported), so a green run also proves
the check can go red. The Scoop check needs the network (HEAD requests to `raw.githubusercontent.com`, no token);
only HTTP 404 means a missing package, anything else is reported as a network error.

Every chezmoi call in these tests uses a temporary config whose age identity does not exist. The host's own key is
never used, so a check that would decrypt fails on the host exactly as in CI.

## Never decrypt in CI

The repo is public (rule in [`AGENTS.md`](../AGENTS.md)). CI sets `CI`, and the `{{ if env "CI" }}` block in
`home/.chezmoiignore` drops every target that needs decryption:

| Target | Why |
|---|---|
| `.ssh/id_ed25519`, `.ssh/id_ed25519.pub` | Encrypted files |
| `.config/git/user.gitconfig` | Git identity and signing key, decrypted from `.encrypted-data.toml.age`; `.gitconfig` includes it, and git skips the missing file |
| `.chezmoiscripts/windows/decrypt-private-key.ps1`, `.chezmoiscripts/linux/decrypt-private-key.sh` | Decrypt the age identity with a passphrase |
| `.chezmoiscripts/windows/add-ssh-key.ps1` | Uses the decrypted private key |
| `.chezmoiscripts/windows/install-wsl.ps1` | Not decryption: the hosted runner cannot install a WSL distro |

`tests/static/NoDecryptInCi.Tests.ps1` fails when, with `CI` set, a managed file is `encrypted_*` or contains
`decrypt`, or when the set of targets the block drops differs from this table. **Adding a decryption point** (e.g. GPG
keys): add its target to the block and to the test's expected list, then to this table. The workflow also fails if
an age identity, `~/.ssh/id_ed25519`, or a git `user.email` / `user.signingkey` exists on the runner.

## CI

One job on `windows-latest`, no secrets, `contents: read`. Order: assert no identity → Scoop (`-RunAsAdmin`) →
chezmoi and Pester 6 → static and unit tests → `chezmoi init --apply --source $GITHUB_WORKSPACE` → post-apply
tests (`Installed-Apps-Modules.Tests.ps1`, `Profile.Tests.ps1`) → assert nothing was decrypted.

The runner is elevated, so CI does **not** prove that apply works without admin; the VM does. CI never runs
`install.ps1`, which clones the default branch instead of the PR.

## VM

- `cd tests; vagrant up dotfiles-windows --provision` (`vagrant reload --provision` on an existing VM). The
  provisioner creates the standard user `dotfiles` (password `dotfiles`, local throwaway VM only) and shares the repo
  root at `C:\dotfiles-src`. Start it from the main checkout, not a worktree: a worktree's `.git` is a file that
  points to a host path.
- Log in to the VM window as `dotfiles` and run
  `powershell -ExecutionPolicy Bypass -File C:\vagrant\run-tests.ps1 -BRANCH <branch>`; answer the key passphrase.
  `run-tests.ps1` copies `C:\dotfiles-src` to `~\.local\share\chezmoi` (uncommitted changes included), so
  `chezmoi init` skips the clone; for the `vagrant` account the share in its profile is used as before.
- `run-tests.ps1` downloads only `install.ps1` from GitHub (`.../refs/heads/<branch>/install.ps1`), so push changes
  to `install.ps1` before testing them.
- After the run, check: all Pester tests pass, no UAC prompt, `git config user.name` / `user.email` are set and a
  signed commit verifies (never print `user.signingkey`), the apply output ends with the administrator reminder.
- Run the admin scripts from a second, administrator account, as an IT administrator would.

Tests under `tests/windows/` that check a completed install (`Installed-Apps-Modules.Tests.ps1`,
`Profile.Tests.ps1`) run after apply only: in CI and in the VM.

## Unit tests against the working copy

Module tests (`tests/windows/Write-Pretty/`, `tests/windows/PackageUpdates/`) run on the host without applying
chezmoi: prepend the source module directory to `PSModulePath` in a child shell. Only Pester 6 is supported; the
test files enforce it with `#Requires`. Name the folders: `tests/windows` itself holds the post-apply tests.

```powershell
pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; $env:PSModulePath = "$PWD\home\readonly_Documents\PowerShell\Modules;$env:PSModulePath"; Invoke-Pester tests/windows/Write-Pretty, tests/windows/PackageUpdates -Output Detailed'
```

Without the `PSModulePath` prefix, `Import-Module` loads the *installed* copy from `~/Documents`. The
`PackageUpdates` tests mock `scoop`, `dotnet`, the Gallery and NuGet; real updates are checked in the VM.

The admin-setup tests load scripts from the source, so they need no `PSModulePath` prefix. They mock `wsl`,
`ssh-add`, the service and the registry, and run the aggregate against stub item scripts; the real admin scripts
run only in the VM:

```powershell
pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; Invoke-Pester tests/windows/AdminSetup -Output Detailed'
```
