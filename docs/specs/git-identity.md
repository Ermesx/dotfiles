# Spec: Work email on the work machine, personal email on github.com

Issue: [#60](https://github.com/Ermesx/dotfiles/issues/60) · Status: Approved · Date: 2026-11-27 ·
Plan: [`git-identity.plan.md`](git-identity.plan.md)

## Goal

1. **Work machine:** the work email by default, for everything git.
2. **github.com on the work machine:** the personal email. github.com is public and non-commercial, no work happens
   there, and the personal account is logged in; my own dotfiles must carry my own identity.
3. **Private machine:** unchanged. Nothing work-related exists on it, not even encrypted in the source.

## Decisions (2026-11-27)

| # | Question | Agreed | Rejected alternative and why |
|---|---|---|---|
| D1 | What tells the machines apart | **The work email, asked once at `chezmoi init`** on the work machine; an empty answer means a private machine | Both emails and the GHES host in `.encrypted-data.toml.age` (issue #60 as first written): the ciphertext is in every clone, so the private machine holds it too |
| D2 | Where the work email lives | **Only in that machine's chezmoi config** (`[data.git] work_email`) | Encrypted in the repo: same reason as D1, and a new decryption point in CI |
| D3 | What selects the personal email on the work machine | **A github.com remote**, any remote of the repo | A list of repositories or a path: needs maintenance per repo |
| D4 | SSH key and `allowed_signers` | **Unchanged**: one key, one line with the personal email | Two principals for the same key: git always reports the first line, so the label is wrong for one of the two emails (F4) and nothing else changes. Two keys: `~/.ssh/config`, a `signingkey` per account, for a cosmetic label |

## Facts (verified 2026-11-27: git 2.55.0.windows.5, chezmoi v2.73.1, Windows OpenSSH)

| # | Fact | Source |
|---|---|---|
| F1 | `includeIf "hasconfig:remote.*.url:<p>"` with `https://github.com/**`, `git@github.com:*/**` and `ssh://git@github.com/**` matches the three clone URL forms of github.com, not `github.com.evil`, not a repo without a remote. `git@H:**` does not match `git@H:org/r.git`. Not matched: `ssh://…:22/`, `ssh://H/` (no user), `https://user@H/`, an upper-case host | probes in temp repos with `GIT_CONFIG_GLOBAL` |
| F2 | Any remote counts, not only `origin` | same probe |
| F3 | Later wins. `[include]` of the personal file, then `[user] email = <work>`, then the `includeIf` blocks re-including the personal file: work by default, personal on github.com. An `includeIf` placed before a later `[user] email` is overridden by it | probe |
| F4 | `git verify-commit` finds the principal by **key**, not by the committer email, and reports the first matching line: a commit by either email is `G`; the label is the first principal. Without `allowedSignersFile`: `U`, exit 1 | probe with a throwaway key, both line orders |
| F5 | A real `chezmoi init` **waits on a prompt even with stdin closed**; `init --no-tty` reads the answers from stdin (an Enter accepts the default, a closed stdin is an `EOF` error, for `promptStringOnce` and `promptMultichoiceOnce` alike). `execute-template --init` returns the default without asking, so it proves nothing about `init`. `install.ps1` passes `--no-tty` only when `CI=true` (`install.ps1:29`); the VM runner and a manual run do not. So any run that must not ask has to skip the prompt, which is what `DOTFILES_PROFILES` and `DOTFILES_GIT_WORK_EMAIL` do | probes into a temp config and destination; `install.ps1:29-30` |
| F6 | Rule of R1 on a real `init`: `DOTFILES_PROFILES` set, no email variable → `work_email = ""`, exit 0; `DOTFILES_GIT_WORK_EMAIL=w@x` → `"w@x"`; a later init with only `DOTFILES_PROFILES` keeps `"w@x"` | same probes |
| F7 | `promptStringOnce . "git.work_email" …` stores under `[data.git]` and returns the stored answer on later inits | probe |
| F8 | `Selection.Tests.ps1` and `NewPicks.Tests.ps1` assert exit codes and single fields of the written config, not the whole file | `grep` of `tests/static` |

## Requirements

- **R1 Prompt.** `home/.chezmoi.toml.tmpl` writes `[data.git] work_email`, chosen in this order:
  1. `DOTFILES_GIT_WORK_EMAIL`, when set;
  2. else, when `DOTFILES_PROFILES` is set (the run is non-interactive, D15 of #20; the picks prompts follow the same
     rule, `.chezmoi.toml.tmpl:76-89`): the stored value, `""` if none, no prompt;
  3. else `promptStringOnce . "git.work_email"`, prompt text naming the empty answer as "private machine",
     default `""`.

  The value is trimmed, so an answer of spaces means a private machine. A non-empty value must be a plain address
  (`[A-Za-z0-9._%+'-]+@[A-Za-z0-9.-]+`) or init fails: it is written unescaped into `~/.gitconfig`, where a newline
  would add settings and `#`, `;`, `"` or `\` would break the line. The check covers every source, the stored value
  included. CI, the VM and an unattended install all pass
  the email in the variable; `--no-tty` is not a second mechanism. Passing the email in CI must work: with `CI=true`,
  `DOTFILES_PROFILES` and `DOTFILES_GIT_WORK_EMAIL` set, `chezmoi init --no-tty` stores that email (test
  `reads the email under the CI conditions`).
- **R2 `home/dot_gitconfig.tmpl`.** With `git.work_email` empty or missing (read with `dig`), the output is
  byte-identical to today. With a value, right after the `[include]` of `user.gitconfig`:

  ```gitconfig
  [user]
  email = <work email>
  [includeIf "hasconfig:remote.*.url:https://github.com/**"]
  path = ~/.config/git/user.gitconfig
  [includeIf "hasconfig:remote.*.url:git@github.com:*/**"]
  path = ~/.config/git/user.gitconfig
  [includeIf "hasconfig:remote.*.url:ssh://git@github.com/**"]
  path = ~/.config/git/user.gitconfig
  ```

  The order is fixed by F3. The header comment of the file gets a clause: on a work machine the default email comes
  from the chezmoi config.
- **R3 `tests/run-tests.ps1`** gets `-WorkEmail`, passed as `DOTFILES_GIT_WORK_EMAIL` and removed from the session
  first, like the profile variables.
- **R4 Tests** (`tests/static/GitIdentity.Tests.ps1`):
  - the config template: R1 in each of its three branches, and a stored value survives a plain `init`;
  - `dot_gitconfig.tmpl`: no data and `work_email = ""` render identically to each other and contain no `[user]` and
    no `includeIf`; with a value, the block of R2 follows the `[include]`;
  - behaviour: against the rendered file with a stub `user.gitconfig` (absolute, `C:/…` form: git on Windows ignores
    an MSYS `/c/…` path without an error), `git config user.email` is personal for the three github.com forms and
    work for another host, for a repo without a remote and for a repo whose second remote is github.com's.
- **R5 CI.** In `.github/workflows/ci.yml`:
  - the "Apply dotfiles" step sets `DOTFILES_GIT_WORK_EMAIL: ci-work@example.invalid` (a test value, not a secret), so
    the real path `install.ps1` → `chezmoi init --no-tty --apply` runs with a work email;
  - a post-apply test, `tests/windows/GitIdentityApplied.Tests.ps1`, runs in CI and on the VM. It reads
    `chezmoi data` → `.git.work_email`. Empty: no `user.email`, no `includeif.*` in the global config. Set: three
    `includeif.*` entries, `user.email` of a repo without a remote equals it, and where `~/.config/git/user.gitconfig`
    exists (the VM) a github.com repo gets another email;
  - the "Assert nothing was decrypted" step (own commit, it relaxes one condition of a security guard) sets the same
    variable and requires: `~/.config/chezmoi/key.txt`, `~/.ssh/id_ed25519`, `~/.config/git/user.gitconfig` and
    `~/.config/git/allowed_signers` absent (the last was missing since #55); `user.signingkey` empty; `user.email`
    empty **or equal to the variable**. A decrypted real email differs from the test value, so it still trips the guard;
  - a static test pins that `install.ps1` passes `--no-tty` only when `$env:CI -eq 'true'`.
- **R6 Docs.** `docs/chezmoi.md` (Encryption, identity paragraph): the work machine, the prompt, that the work email
  is local config and not repo data, that an empty answer (an accidental Enter too) marks the machine private until
  `chezmoi init --prompt`. `docs/testing.md`: `DOTFILES_GIT_WORK_EMAIL` and `-WorkEmail`.
- **R7 VM acceptance.** With `-WorkEmail`, on the real `~/.gitconfig`: work email in a repo with a non-github.com
  remote and in one without a remote; personal in a github.com repo in the three forms; a signed commit under each
  email passes `git verify-commit`. Without it: `~/.gitconfig` as before.

Untouched: `user.gitconfig.tmpl`, `allowed_signers.tmpl`, `install.ps1`, `.encrypted-data.toml.age`, the CI block of
`.chezmoiignore`, the list in `NoDecryptInCi.Tests.ps1`. No new decryption point.

## Manual steps (owner)

- Work machine: `chezmoi init --prompt` once and enter the work email.
- GHES account: add the same public key as an authentication **and** signing key and verify the work email, so GHES
  shows commits as Verified. That is the server's check, not `allowed_signers`.

## Accepted trade-offs

- A repository with no remote gets the work email, commits made before `origin` exists included. Nothing work-related
  is created on github.com, so nothing reaches it.
- A repo with any github.com remote gets the personal email (F2).
- Remote URL forms outside F1 fall back to the work email. GitHub offers only the three matched forms.
- A machine initialised before this change is asked once, at its next `chezmoi init` without `DOTFILES_PROFILES`.
  `Selection.Tests.ps1` stores an empty answer in its helper for the same reason.
- The work email is plain text in the work machine's `~/.config/chezmoi/chezmoi.toml` and `~/.gitconfig`.
- On a work machine `git verify-commit` labels every commit with the personal email (F4); the check passes.
- The one SSH key is also on the private machine.

## Out of scope

- `gh auth` and any GHES CLI config.
- Rewriting the author of past commits.
- A third account or host.
