# Git identity per machine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline, this session) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A machine initialised with a work email uses it for git by default and the personal email for github.com remotes; a machine initialised without one is unchanged.

**Architecture:** The work email is one answer to a `chezmoi init` prompt, stored under `[data.git]` in that machine's chezmoi config and supplied non-interactively through `DOTFILES_GIT_WORK_EMAIL`. `home/dot_gitconfig.tmpl` reads it and, only when set, adds a default `[user] email` plus three github.com `includeIf` blocks that re-include the personal `user.gitconfig`. Nothing is decrypted; no encrypted file changes.

**Tech Stack:** chezmoi v2.73.1 templates, git 2.55 (`includeIf hasconfig:remote.*.url`), PowerShell 7, Pester 6, GitHub Actions.

**Spec:** [`git-identity.md`](git-identity.md) · Issue #60

## Global Constraints

- Run chezmoi with `--source <repo root>`; never `chezmoi apply` or `install.ps1` on the host (AGENTS.md).
- Never decrypt in CI. No new decryption point. `user.gitconfig.tmpl`, `allowed_signers.tmpl`, `install.ps1`, `.encrypted-data.toml.age`, the CI block of `home/.chezmoiignore` and `NoDecryptInCi.Tests.ps1` stay untouched.
- Email resolution order (spec R1): `DOTFILES_GIT_WORK_EMAIL`; else, when `DOTFILES_PROFILES` is set, the stored value or `""` without a prompt; else `promptStringOnce`. The value is trimmed. `--no-tty` is a test-command detail, not a second mechanism.
- Block order in `dot_gitconfig.tmpl` (spec F3): `[include]`, `[user] email`, then the three `includeIf`; later wins. Patterns verbatim: `https://github.com/**`, `git@github.com:*/**`, `ssh://git@github.com/**`; never `git@github.com:**`.
- Test fixtures that give git a `path =` use `C:/…` form; an MSYS `/c/…` path is ignored without an error.
- Config-template tests run `chezmoi init --no-tty` into a temp config and destination (as `Selection.Tests.ps1:30`); `execute-template` proves nothing about prompts.
- The CI work email is the test value `ci-work@example.invalid`; never a real address.
- Run commands through PowerShell, one per call (the worktree guard rejects compound Bash commands that name git). Commit locally after each task, Conventional Commits with scope, no push.
- Narrow test: `pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; Invoke-Pester <file> -Output Detailed'`.

## Review Focus

1. A config with no `[data.git]` (a machine initialised before this change) renders `dot_gitconfig.tmpl` identically to today: Task 2.
2. `DOTFILES_PROFILES` set with a stored email and no variable keeps the stored email and never prompts: Task 1.
3. An answer of spaces means a private machine; an email with `+` and `.` reaches `git config` unchanged: Tasks 1 and 2.
4. `github.com.evil`, `https://user@github.com/…` and a repo with no remote get the work email; a repo with a second remote on github.com gets the personal one: Task 2.
5. The decryption guard still throws for any `user.email` other than the injected test value: Task 5.

---

### Task 1: The prompt in `.chezmoi.toml.tmpl`

**Files:**
- Modify: `home/.chezmoi.toml.tmpl` (compute before `[data]`, write `[data.git]` after it)
- Modify: `tests/static/Selection.Tests.ps1` (its helper stores an empty work email: otherwise every init without `DOTFILES_PROFILES` hits the new prompt and fails with EOF under `--no-tty`)
- Create: `tests/static/GitIdentity.Tests.ps1` (its helper stores `profiles` for the same reason, and pipes one Enter to stdin)

**Interfaces:**
- Produces: `.git.work_email` (string, `""` on a private machine) in chezmoi data; test helper `Invoke-Init([hashtable]$Env = @{}, [string]$Existing = '') -> [pscustomobject]@{ Output; ExitCode }`.

- [ ] **Step 1: Write the failing tests.** `Invoke-Init` follows `Selection.Tests.ps1:21-42`: it clears `DOTFILES_PROFILES` and `DOTFILES_GIT_WORK_EMAIL`, sets `$Env`, restores in `finally`, runs `chezmoi --source $root --config <temp> --destination <temp> init --no-tty`, returns the written config. Each test asserts `ExitCode -Be 0` and the `work_email` line:

  | Test | Input | Expected `work_email` |
  |---|---|---|
  | `takes the email from the variable` | `DOTFILES_GIT_WORK_EMAIL=first.last+work@corp.example` | `"first.last+work@corp.example"` |
  | `trims the variable` | `'  w@x  '` | `"w@x"` |
  | `treats spaces as a private machine` | `'   '` | `""` |
  | `defaults to empty when the prompt is answered with Enter` | none; stdin is one Enter (`--no-tty` reads answers from stdin, EOF fails) | `""` |
  | `skips the prompt under DOTFILES_PROFILES` | `DOTFILES_PROFILES=shell` | `""` |
  | `keeps a stored email under DOTFILES_PROFILES` | stored `w@x`, `DOTFILES_PROFILES=shell` | `"w@x"` |
  | `lets the variable override a stored email` | stored `w@x`, variable `v@x` | `"v@x"` |
  | `keeps a stored email on a plain init` | stored `w@x`, nothing set | `"w@x"` |
  | `reads the email under the CI conditions` | `CI=true`, `DOTFILES_PROFILES=shell`, `DOTFILES_GIT_WORK_EMAIL=ci-work@example.invalid` | `"ci-work@example.invalid"` |

- [ ] **Step 2: Run to verify it fails.** Run the file. Expected: FAIL, the written config has no `work_email`.
- [ ] **Step 3: Implement** in `home/.chezmoi.toml.tmpl`: before `[data]`,

  ```
  {{- $workEmail := dig "git" "work_email" "" . -}}
  {{- if env "DOTFILES_GIT_WORK_EMAIL" -}}{{ $workEmail = env "DOTFILES_GIT_WORK_EMAIL" -}}
  {{- else if not (env "DOTFILES_PROFILES") -}}{{ $workEmail = promptStringOnce . "git.work_email" "Work email (empty on a private machine)" "" -}}{{ end -}}
  {{- $workEmail = trim $workEmail -}}
  ```

  and after `[data]` a `[data.git]` section with `work_email = {{ $workEmail | quote }}`. A comment in the style of the file header says why `DOTFILES_PROFILES` skips the prompt (without `--no-tty` a real `init` waits on it, spec F5).
- [ ] **Step 4: Run to verify it passes**, then `tests/static/Selection.Tests.ps1` and `tests/static/NewPicks.Tests.ps1`. Expected: all PASS.
- [ ] **Step 5: Commit** `feat(git): ask for the work email at chezmoi init`

### Task 2: Work default and github.com override in `dot_gitconfig.tmpl`

**Files:**
- Modify: `home/dot_gitconfig.tmpl:1-3`
- Modify: `tests/static/GitIdentity.Tests.ps1`

**Interfaces:**
- Consumes: `.git.work_email` from Task 1.
- Produces: `Get-RenderedGitConfig([AllowNull()][string]$WorkEmail) -> string` (renders `home/dot_gitconfig.tmpl` with a config holding `[data.git] work_email`, `$null` meaning no `[data.git]`; replaces `~/.config/git/user.gitconfig` with the absolute `C:/…` stub path); `Get-RepoEmail([string]$GlobalConfig, [string[]]$Remotes) -> string` (`git init` in `$TestDrive`, add the remotes, return `git config user.email` under `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_NOSYSTEM=1`, restored after). Stub `user.gitconfig`: `[user] email = personal@example.com`.

- [ ] **Step 1: Write the failing tests:**

  | Test | Input | Expected |
  |---|---|---|
  | `renders identically with no data and with an empty email` | `$null` vs `''` | equal |
  | `has no [user] and no includeIf without a work email` | `''` | no `\[user\]`, no `includeIf` |
  | `adds the work block after the include` | `w@x` | order `[include]` → `email = w@x` → three `includeIf` with the exact patterns |
  | `gives the personal email to github.com` | `https://github.com/Ermesx/dotfiles.git`, `git@github.com:Ermesx/dotfiles.git`, `ssh://git@github.com/Ermesx/dotfiles.git` | `personal@example.com` |
  | `gives the work email elsewhere` | `https://ghes.corp.example/o/r.git`, `git@ghes.corp.example:o/r.git`, `https://dev.azure.com/o/p/_git/r`, no remote | `first.last+work@corp.example` |
  | `falls back to work for unmatched forms` | `https://github.com.evil/o/r`, `https://user@github.com/o/r.git` | work |
  | `counts any remote` | `https://ghes.corp.example/o/r` + `https://github.com/o/r` | personal |
  | `leaves everyone personal without a work email` | `''`; github.com and no remote | `personal@example.com` |

- [ ] **Step 2: Run to verify it fails.** Expected: render and behaviour tests FAIL (no `includeIf`).
- [ ] **Step 3: Implement.** Reword the header comment (identity and signing key come from encrypted data; on a work machine the default email comes from the chezmoi config). After `path = ~/.config/git/user.gitconfig` add `{{- with dig "git" "work_email" "" . }}…{{ end }}` containing `[user]`, `email = {{ . }}` and the three `includeIf` blocks, each `path = ~/.config/git/user.gitconfig`. With an empty value the file must stay byte-identical to today: check the whitespace trimming around `[gpg]`.
- [ ] **Step 4: Run to verify it passes**, then `tests/static/Templates.Tests.ps1`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(git): work email by default, personal on github.com`

### Task 3: `-WorkEmail` in the VM runner

**Files:**
- Modify: `tests/run-tests.ps1` (header comment, `param`, the variable cleanup at line 38, the set at line 41)
- Modify: `tests/static/RunTests.Tests.ps1`

**Interfaces:**
- Produces: `-WorkEmail [string]`, exported to the process as `DOTFILES_GIT_WORK_EMAIL`; removed first when absent.

- [ ] **Step 1: Write the failing tests:** `types -WorkEmail as String` (AST, as the test at line 15) → `String`; `removes a leaked DOTFILES_GIT_WORK_EMAIL` → the script text contains `Remove-Item env:DOTFILES_GIT_WORK_EMAIL`.
- [ ] **Step 2: Run** `RunTests.Tests.ps1`. Expected: FAIL.
- [ ] **Step 3: Implement:** `[string]$WorkEmail` in `param`; next to `Remove-Item env:DOTFILES_PROFILES` remove the new variable; `if ($WorkEmail) { $env:DOTFILES_GIT_WORK_EMAIL = $WorkEmail.Trim() }`; one line in the header comment.
- [ ] **Step 4: Run** the same file. Expected: PASS.
- [ ] **Step 5: Commit** `feat(tests): -WorkEmail for the VM runner`

### Task 4: Post-apply test and the email in the CI apply step

**Files:**
- Create: `tests/windows/GitIdentityApplied.Tests.ps1`
- Modify: `tests/static/InstallScripts.Tests.ps1`
- Modify: `.github/workflows/ci.yml` ("Apply dotfiles" step, `:62-69`; "Post-apply tests" list, `:75`)

**Interfaces:**
- Consumes: `.git.work_email` through `chezmoi data --format json`.

- [ ] **Step 1: Write the tests.**
  - `InstallScripts.Tests.ps1`: `passes --no-tty only when CI is true` → the text of `install.ps1` contains `--no-tty` inside the expression conditioned on `$env:CI -eq 'true'`. It passes at once (it pins today's behaviour); that is expected.
  - `GitIdentityApplied.Tests.ps1`, source of truth `.git.work_email`: empty → `git config --global --includes --get user.email` is empty and `git config --global --get-regexp '^includeif\.'` returns nothing; set → three `includeif.*` entries, `user.email` of a repo without a remote equals the value, and when `~/.config/git/user.gitconfig` exists a repo with remote `https://github.com/o/r` reports another email.
- [ ] **Step 2: Run** `InstallScripts.Tests.ps1`. Expected: PASS. The applied test is read, not run (it needs an applied home: CI or VM).
- [ ] **Step 3: Implement the CI change.** In the "Apply dotfiles with install.ps1" step add `DOTFILES_GIT_WORK_EMAIL: ci-work@example.invalid` to `env:`; add `tests/windows/GitIdentityApplied.Tests.ps1` to the "Post-apply tests" `-Path` list.
- [ ] **Step 4: Verify YAML:** `pwsh -NoProfile -Command 'Import-Module powershell-yaml; Get-Content -Raw .github/workflows/ci.yml | ConvertFrom-Yaml | Out-Null'`. Expected: exit 0.
- [ ] **Step 5: Commit** `test(git): applied identity is checked after apply, also in CI`

### Task 5: Relax one condition of the decryption guard (own commit)

**Files:**
- Modify: `.github/workflows/ci.yml:77-87` ("Assert nothing was decrypted")

**Why a separate task:** it changes a security guard; the owner reviews and can revert it alone.

- [ ] **Step 1: Write the scenario check** as a throwaway script under `$env:CLAUDE_JOB_DIR/tmp`: with `GIT_CONFIG_GLOBAL` pointing at a temp gitconfig, the guard body passes for no `user.email`, passes for `user.email = ci-work@example.invalid` with `DOTFILES_GIT_WORK_EMAIL` set to it, and throws for `user.email = someone@else.example` and for any `user.signingkey`.
- [ ] **Step 2: Run it against the current guard.** Expected: the `ci-work@example.invalid` case throws (guard rejects any `user.email`).
- [ ] **Step 3: Implement.** The step gets `env: DOTFILES_GIT_WORK_EMAIL: ci-work@example.invalid` (step variables are not inherited between steps). Throw when any of `~/.config/chezmoi/key.txt`, `~/.ssh/id_ed25519`, `~/.config/git/user.gitconfig`, `~/.config/git/allowed_signers` exists (the last one missing since #55); throw when `git config --global --includes --get user.signingkey` is non-empty; throw when `user.email` is non-empty and not equal to `$env:DOTFILES_GIT_WORK_EMAIL`.
- [ ] **Step 4: Re-run the scenario check and the YAML check.** Expected: the four cases behave as in Step 1; YAML exit 0.
- [ ] **Step 5: Commit** `ci(git): allow only the injected work email in the decryption guard`

### Task 6: Documentation

**Files:**
- Modify: `docs/chezmoi.md` (Encryption, identity bullet near line 33)
- Modify: `docs/testing.md` (decryption table near lines 31-41; VM runner paragraph near line 74)

- [ ] **Step 1: Write** in `chezmoi.md`: the work and private machine, the prompt at `init`, that the email is local config and not repo data, that an empty answer (an accidental Enter too) marks the machine private until `chezmoi init --prompt`, and how to give it unattended (`DOTFILES_GIT_WORK_EMAIL`). In `testing.md`: `-WorkEmail`, the CI variable, the relaxed guard condition, `allowed_signers` among the targets that must not exist.
- [ ] **Step 2: Verify:** `Invoke-Pester tests/static/Docs.Tests.ps1` → PASS, then the whole `tests/static` suite → PASS.
- [ ] **Step 3: Commit** `docs(git): work machine identity and the non-interactive email`, with `Fixes #60`.

## After the tasks (owner)

- VM: `run-tests.ps1 -BRANCH feat/60-git-identity -WorkEmail <email>` and without it; in a scratch repo, the email per remote and `git verify-commit` under both emails (`G`, exit 0). Put the result in the PR description.
- GHES account: the same public key as authentication and signing key, with the work email verified.
- Not verifiable on the host: the real `install.ps1` run in CI and the VM scenario.
