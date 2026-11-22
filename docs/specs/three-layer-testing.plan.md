# Three-Layer Testing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (Native: one session, no per-task subagents) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every change is checked statically on the host and in GitHub Actions, CI applies the dotfiles on a clean `windows-latest` without ever decrypting, and the VM runs the install as a standard user.

**Architecture:** A `CI` block in `home/.chezmoiignore` drops every target that needs decryption (the git identity moves to an included file so `.gitconfig` itself has no `decrypt`). `tests/static/StaticChecks.psm1` holds parameterised checks (render, no-decrypt guard, package schema, Scoop manifests, Markdown links) that Pester runs against the repo and against `TestDrive:` fixtures. One `ci.yml` job runs the static layer, `chezmoi init --apply`, then the post-apply tests. Vagrant provisions a standard user who runs `run-tests.ps1` from a copy of the working tree.

**Tech Stack:** PowerShell 7, Pester 6, chezmoi 2.73 templates, GitHub Actions (`windows-latest`), Scoop, Vagrant + VirtualBox.

**Spec:** [`docs/specs/three-layer-testing.md`](three-layer-testing.md) (R1–R9, C1–C4 confirmed, D1–D9 confirmed 2026-11-22).

## Global Constraints

- Branch `feat/47-three-layer-testing` off `develop`. Conventional Commits with a scope; the docs commit carries `Fixes #47`.
- **Never decrypt.** Every chezmoi call in a test uses `--config` → temp file with `encryption = "age"` and `[age] identity` set to a path that does not exist (recipient copied from `home/.chezmoi.toml.tmpl`). Never `chezmoi apply` / `install.ps1` on the host.
- `ci.yml`: no `secrets.`, no `vars.`; `permissions: contents: read`.
- `*.ps1`, `*.psm1`, `*.ps1.tmpl`: CRLF, no BOM (`git ls-files --eol <f>` → `i/crlf`). `*.yml`, `*.md`, other `*.tmpl`, `Vagrantfile`: LF.
- Always `chezmoi --source .` (or `--source <repo root>` in tests) — never the installed source.
- Test header: `#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }`; tests import the module with `Import-Module "$PSScriptRoot/StaticChecks.psm1" -Force`.
- Static command (host and CI): `pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; Invoke-Pester tests/static -Output Detailed'`.
- `CI=true` is set only inside a check's scope and restored in `finally`.

## Review Focus

1. **Host check passes because the host has the key** → every chezmoi call uses the no-key config; Task 1 test `reports an unguarded decrypt template` runs on the host where `key.txt` exists and must still report it.
2. **CI block drops more than intended** (`.ssh/*`, a typo matching nothing) → Task 1 test `ignores exactly the agreed targets in CI` compares the set diff with the D2 list.
3. **A future decryption point** (e.g. GPG, #49) added without a CI entry → Task 1 fixture tests for both `encrypted_` and `decrypt`; Acceptance 4 proves it in a real run.
4. **Profile loads with hidden non-terminating errors** → Task 4 `Profile.Tests.ps1` fails on any error record written while loading and prints them; `$Error` is not counted.
5. **Network flake reads as a missing package** → only 404 means `'no manifest'`, other statuses retry then report `'network error'`; Task 3 test `reports a server error as a network error`.

---

### Task 1: CI mode in the source and the no-decrypt guard (R1, R2, R3 guard part, R4 `NoDecryptInCi`)

**Files:**
- Create: `tests/static/StaticChecks.psm1`, `tests/static/NoDecryptInCi.Tests.ps1`, `home/dot_config/git/user.gitconfig.tmpl`
- Modify: `home/dot_gitconfig.tmpl:1-3`, `home/.chezmoiignore` (append)

**Interfaces:**
- Produces (private, used by later tasks): `Get-NoKeyConfig` → `[string]` path of a `.toml` file created once per module load in `[IO.Path]::GetTempPath()` (`encryption = "age"`, `[age] identity` = a non-existent path, the repo's recipient, `[warnings] configFileTemplateHasChanged = false`); `Invoke-ChezmoiCi -Source <string> -Arguments <string[]> [-InputText <string>] [-NoCi]` → `[pscustomobject]@{ Output = [string[]] (stdout only); Error = [string] (stderr); ExitCode = [int] }`. It sets `CI=true`, or with `-NoCi` **removes** `CI` (GitHub sets it for the whole job), restores the previous value in `finally`, and always passes `--config (Get-NoKeyConfig) --source $Source`.
- Produces (exported): `Get-CiDecryptionViolation -Source <string>` → `[string[]]`; `Get-CiIgnoredTarget -Source <string>` → `[string[]]` sorted.

- [ ] **Step 1: Write `NoDecryptInCi.Tests.ps1`.** `BeforeAll`: `$root = Resolve-Path "$PSScriptRoot/../.."`; helper `New-Fixture([hashtable]$files)` writes `TestDrive:\<guid>\.chezmoiroot` = `home` and each `home/<relative> = <content>`, returns the folder.
  - `It 'finds no decryption in the repo with CI set'`: `Get-CiDecryptionViolation -Source $root | Should -BeNullOrEmpty`.
  - `It 'ignores exactly the agreed targets in CI'`: `Get-CiIgnoredTarget -Source $root | Should -Be @('.chezmoiscripts/windows/add-ssh-key.ps1', '.chezmoiscripts/windows/decrypt-private-key.ps1', '.chezmoiscripts/windows/install-wsl.ps1', '.config/git/user.gitconfig', '.ssh/id_ed25519', '.ssh/id_ed25519.pub')`.
  - `It 'reports an unguarded decrypt template'`: fixture `dot_leak.tmpl = '{{ "x" | decrypt }}'` → result `Should -Be 'dot_leak.tmpl'`.
  - `It 'reports decrypt in a shared template'`: fixture `.chezmoitemplates/t.tmpl` with the same text → contains `.chezmoitemplates/t.tmpl`.
  - `It 'reports a plain script that decrypts'`: fixture `.chezmoiscripts/run_once_x.ps1 = 'chezmoi age decrypt --passphrase k.age'` → contains `.chezmoiscripts/run_once_x.ps1`.
  - `It 'reports an encrypted file that CI does not ignore'`: fixture `encrypted_secret.age = 'not-really-age'` → contains `encrypted_secret.age`.
- [ ] **Step 2: Run the static command → FAIL** (module missing).
- [ ] **Step 3: Implement the module part.** `Get-CiDecryptionViolation`: `managed --include=files,scripts,symlinks --path-style source-relative` via `Invoke-ChezmoiCi` (directories are not targets that can decrypt, and their presence depends on their children); root = `<Source>/<content of .chezmoiroot>` when present; a path whose leaf contains `encrypted_` is a violation; any other managed **file** (template, script or plain file) whose content matches `\bdecrypt\b` is a violation — a plain script can run `chezmoi age decrypt` too; plus every file under `<root>/.chezmoitemplates/` that matches. `Get-CiIgnoredTarget`: `managed --include=files,scripts,symlinks` with `-NoCi` minus the same with CI, `Sort-Object`. Throw when a chezmoi call exits non-zero (message = its output). Export only the `Get-*` functions.
- [ ] **Step 4: Run → FAIL on the repo tests only** (gitconfig has `decrypt`; ignored set empty). Fixture tests PASS. If `managed` errors on the fake `encrypted_` fixture instead (spec Risks), take the `encrypted_` candidates from the source file names under the root and keep those that `managed` without CI-ignore would list; note it in the PR.
- [ ] **Step 5: Source changes.** Create `home/dot_config/git/user.gitconfig.tmpl` (LF): `[user]` then lines 2–3 of `dot_gitconfig.tmpl` moved verbatim. `dot_gitconfig.tmpl` begins `[include]` / `path = ~/.config/git/user.gitconfig` and has no `[user]`. Append to `home/.chezmoiignore` the block from spec D2: `{{- if env "CI" }}`, `# CI: needs decryption (docs/testing.md)` + six targets, `# CI: the runner cannot` + `.chezmoiscripts/windows/install-wsl.ps1`, `{{- end }}`, appended after the existing OS `{{- end -}}`.
- [ ] **Step 6: Run → PASS.** Also: `chezmoi --source . managed --include=all` (no CI) differs from `develop` only by `.config/git` and `.config/git/user.gitconfig`; `git grep -n decrypt -- home` → the two decrypt scripts and `user.gitconfig.tmpl` only.
- [ ] **Step 7: Commit** `feat(tests): skip every decryption point when CI is set, with a guard test`.

### Task 2: Template render check (R3 render part, R4 `Templates`)

**Files:**
- Modify: `tests/static/StaticChecks.psm1`
- Create: `tests/static/Templates.Tests.ps1`

**Interfaces:**
- Consumes: `Invoke-ChezmoiCi` (Task 1).
- Produces: `Get-TemplateRenderFailure -Source <string>` → `[pscustomobject[]]` with `Path` (source-relative), `Error`.

- [ ] **Step 1: Write `Templates.Tests.ps1`.** Same `New-Fixture` helper as Task 1 (copy it; two files do not justify a shared helper).
  - `It 'renders a template that CI ignores'`: fixture `.chezmoiignore = '{{ if env "CI" }}.x{{ end }}'` and `dot_x.tmpl = '{{ if }}'` → one result, `Path` `dot_x.tmpl`.
  - `It 'renders every template in the repo with CI set'`: `Get-TemplateRenderFailure -Source $root | Should -BeNullOrEmpty`.
  - `It 'reports a broken template'`: fixture `dot_broken.tmpl = '{{ if }}'` → one result, `Path` `dot_broken.tmpl`, `Error` not empty.
  - `It 'reports a broken shared template'`: fixture `.chezmoitemplates/x.tmpl = '{{ end }}'` → `Path` `.chezmoitemplates/x.tmpl`.
- [ ] **Step 2: Run → FAIL** (function missing).
- [ ] **Step 3: Implement** per R3: the set is every `*.tmpl` under the root (managed or ignored — a CI-ignored template such as `install-wsl` must still be rendered) **except** files matching `\bdecrypt\b` (Task 1 guarantees those are ignored in CI), plus `.chezmoitemplates/*` and every `.chezmoiignore`; `.chezmoi.toml.tmpl` with `execute-template --init`; each rendered with CI on and the no-key config, with `-InputText (Get-Content -Raw <file>)`; non-zero exit → a result.
- [ ] **Step 4: Run → PASS** (repo and fixtures).
- [ ] **Step 5: Commit** `feat(tests): render every template in the static layer`.

### Task 3: Package schema and Scoop manifests (R3 package part, R4 `Packages`)

**Files:**
- Modify: `tests/static/StaticChecks.psm1`
- Create: `tests/static/Packages.Tests.ps1`

**Interfaces:**
- Consumes: `Invoke-ChezmoiCi` (Task 1) for `data --format json`.
- Produces: `Get-PackagesData -Source <string>` → the `packages` node of `chezmoi data --format json` (CI on, no-key config); `Get-PackagesSchemaProblem -Packages <object>` → `[string[]]`; `Get-ScoopItemProblem -Item <string[]> [-KnownBucket <hashtable>]` → `[pscustomobject[]]` `Item`, `Problem` (`-KnownBucket` defaults to `buckets.json`, name → GitHub URL).

- [ ] **Step 1: Write `Packages.Tests.ps1`.** `BeforeAll`: `$packages = Get-PackagesData -Source $root`. Fixture objects are built from JSON strings with `ConvertFrom-Json`.
  - `It 'accepts the repo packages'`: schema result empty.
  - `It 'reports <Case>'` `-ForEach` with JSON fixtures: method `brew` under `windows`; method `scoop` under `global`; platform `macos`; platform key other than `profiles` (`windows.extra: {}`); `pick` on the `profiles` node (`windows.profiles.pick: true`); `pick: "yes"`; `wsl: ["a","b"]`; `scoop: "git"` (scalar). Each → exactly one message containing the offending key.
  - `It 'finds every Scoop item of the repo'`: all `windows.profiles.*.scoop` items → `Get-ScoopItemProblem` empty.
  - `It 'reports a missing manifest'`: `main/no-such-app-xyz` → `Problem` `'no manifest'`.
  - `It 'reports a server error as a network error'`: `Mock Invoke-WebRequest -ModuleName StaticChecks { [pscustomobject]@{ StatusCode = 503 } }`, item `main/git` → `Problem` matches `^network error 503`, `Should -Invoke Invoke-WebRequest -ModuleName StaticChecks -Times 3` (mock `Start-Sleep` too).
  - `It 'reports an unknown bucket without a request'`: `-KnownBucket @{ main = 'https://github.com/ScoopInstaller/Main' }`, item `nosuch/app`, `Mock Invoke-WebRequest -ModuleName StaticChecks` → `Problem` `'unknown bucket'`, `Should -Invoke Invoke-WebRequest -ModuleName StaticChecks -Times 0`.
- [ ] **Step 2: Run → FAIL** (functions missing).
- [ ] **Step 3: Implement** per R3/D5: unprefixed item → `main`; manifest URL `https://raw.githubusercontent.com/<owner>/<repo>/HEAD/bucket/<app>.json` from the bucket's GitHub URL; `Invoke-WebRequest -Method Head -SkipHttpErrorCheck`: 200 = found, 404 = `'no manifest'`; any other status or exception is retried twice (2 s apart), then reported as `'network error <status>'` — never as a missing package. `buckets.json` from `https://raw.githubusercontent.com/ScoopInstaller/Scoop/master/buckets.json`, fetched once per call.
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** `feat(tests): check the packages.yaml schema and that every Scoop item exists`.

### Task 4: Post-apply profile test and the CI workflow (R5, R6, R7)

**Files:**
- Create: `tests/windows/Profile.Tests.ps1`, `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `tests/static` (Tasks 1–3), `tests/windows/Installed-Apps-Modules.Tests.ps1` (unchanged).

- [ ] **Step 1: Write `Profile.Tests.ps1`:** `It 'loads the PowerShell profile without errors'`: `$out = pwsh -NoLogo -NoProfile -Command '. $PROFILE' 2>&1`; `$errors = @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })`; `$LASTEXITCODE | Should -Be 0`; `$errors | Should -BeNullOrEmpty -Because ($errors | Out-String)`. Do **not** count `$Error`: `-ErrorAction SilentlyContinue` probes (e.g. `Get-EventSubscriber` in `check-updates.ps1.tmpl`) record there without being failures.
- [ ] **Step 2: Run it on the host** (read-only: loads the installed profile) → PASS. A failure here is a real profile bug: stop and report it.
- [ ] **Step 3: Write `ci.yml`** per R5/R6, name `ci`, one job `windows`, steps in the R6 order. Scoop: `& ([scriptblock]::Create((irm get.scoop.sh))) -RunAsAdmin`, then `"$HOME\scoop\shims" >> $env:GITHUB_PATH`. Pester runs use `New-PesterConfiguration` with `Run.Exit = $true` and `Output.Verbosity = 'Detailed'`. Apply: `chezmoi init --apply --source $env:GITHUB_WORKSPACE --no-tty`. Post-apply step refreshes `PATH` like `tests/execute-pester.ps1`. Identity checks: `if (Test-Path …) { throw … }`; after apply also throw when `git config --global --get user.signingkey` or `user.email` returns anything (the git identity never reaches CI).
- [ ] **Step 4: Static check of the workflow:** `git grep -n -E 'secrets\.|vars\.' -- .github/workflows/ci.yml` → nothing; YAML parses (`ConvertFrom-Yaml` from powershell-yaml on the host).
- [ ] **Step 5: Commit** `ci(workflow): add the windows-latest workflow with static, apply and post-apply tests`.

### Task 5: VM standard user (R8)

**Files:**
- Modify: `tests/Vagrantfile` (windows block), `tests/run-tests.ps1`

- [ ] **Step 1: Vagrantfile:** `windows.vm.synced_folder "..", "C:/dotfiles-src", type: "virtualbox"`; `windows.vm.provision "shell", privileged: true, inline:` PowerShell that creates `dotfiles` with password `dotfiles` (`New-LocalUser … -PasswordNeverExpires`, `Add-LocalGroupMember -Group Users`) only when `Get-LocalUser dotfiles -ErrorAction SilentlyContinue` is null. A comment states the password is for the throwaway local VM (spec D8).
- [ ] **Step 2: `run-tests.ps1`:** before the install, `$src = Join-Path $HOME '.local\share\chezmoi'`; when it is missing and `C:\dotfiles-src` exists, `New-Item -ItemType Directory -Force (Split-Path $src) | Out-Null`, then `Copy-Item C:\dotfiles-src $src -Recurse` (comment: a standard user cannot read the `vagrant` profile's sync; the copy keeps uncommitted changes and makes `chezmoi init` skip the clone).
- [ ] **Step 3: Check:** `run-tests.ps1` parses with zero errors; `cd tests; vagrant validate` → `Vagrantfile validated successfully.` (no VM start).
- [ ] **Step 4: Commit** `test(vm): provision a standard user and run the install from a working-tree copy`.

### Task 6: Docs and link check (R9, R4 `Docs`)

**Files:**
- Modify: `tests/static/StaticChecks.psm1`, `docs/testing.md`, `AGENTS.md` (Commands table), `docs/chezmoi.md` (Encryption), `docs/architecture.md:31`
- Create: `tests/static/Docs.Tests.ps1`

**Interfaces:**
- Produces: `Get-BrokenMarkdownLink -Path <string>` → `[string[]]` (relative targets only; `http(s):` and `#anchor` skipped; `#…` stripped from file links).

- [ ] **Step 1: Write `Docs.Tests.ps1`:** `It 'has no broken links in <_>' -ForEach 'AGENTS.md', 'docs/testing.md'` (resolved against `$root = Resolve-Path "$PSScriptRoot/../.."`) → file exists and result empty; `It 'reports a broken link'`: fixture `TestDrive:\a.md` = `[x](missing.md) [y](https://example.com)` → `Should -Be 'missing.md'`.
- [ ] **Step 2: Run → FAIL;** implement `Get-BrokenMarkdownLink` (regex `\]\(([^)\s]+)\)`, resolve against the file's folder); **run → PASS.**
- [ ] **Step 3: Rewrite `docs/testing.md`** per R9; keep the existing unit-test commands. Update `AGENTS.md` (row `Static tests` → the static command), `docs/chezmoi.md` Encryption (git identity in `~/.config/git/user.gitconfig`; CI block), `docs/architecture.md:31`.
- [ ] **Step 4: Run the static command → PASS.**
- [ ] **Step 5: Commit** `docs(testing): describe the three test layers and the CI no-decryption rule`, body `Fixes #47`.

### Task 7: Code review before the PR

- [ ] **Step 1:** run the `code-review` skill on the branch against `develop`.
- [ ] **Step 2:** fix every confirmed finding; rerun the static command and `Profile.Tests.ps1`; commit (`fix(tests): …`). A rejected finding goes into the PR description with the reason.

### Task 8: Pull request and CI proof (Acceptance 3–4)

- [ ] **Step 1:** push, open a PR to `develop` with scope, D1–D9, host results and code-review outcome.
- [ ] **Step 2:** wait for `ci` (`gh pr checks --watch`) → green. On red: fix, never skip a target to get green unless it is in D2. Record the apply step duration; apply D7 (cache only if > 15 min, as a separate commit).
- [ ] **Step 3: Deliberate attempt:** commit `home/dot_leak.tmpl` = `{{ "x" | decrypt }}`, push, confirm `ci` fails in the static step on `NoDecryptInCi`; `git revert` it, push, confirm green. Link both runs in the PR.

### Task 9: VM acceptance (owner, by hand)

Spec *Acceptance* 5, from the main checkout (in a worktree `.git` is a file pointing to a host path, so the copied source is not a repo): `cd tests; vagrant up dotfiles-windows --provision` (or `vagrant reload --provision` on an existing VM, to mount the new share); log in to the VM window as `dotfiles`; `powershell -ExecutionPolicy Bypass -File C:\vagrant\run-tests.ps1 -BRANCH feat/47-three-layer-testing`; answer the key passphrase; all Pester tests pass, no UAC prompt, `git config user.name` and `user.email` are set, a signed commit works (`git commit --allow-empty -m t` in a scratch repo, then `git log --show-signature -1`) — never print `user.signingkey`; `run-tests` shows the admin reminder. Results go into the PR description.
