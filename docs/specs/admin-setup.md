# Spec: Admin-only setup run outside chezmoi — aggregate script, end-of-apply reminder, per-user function

Issue: [#44](https://github.com/Ermesx/dotfiles/issues/44) · ADR: [ADR-0003](../adr/0003-windows-packages-via-scoop.md) ·
Status: Draft · Date: 2026-11-22 · Plan: [`admin-setup.plan.md`](admin-setup.plan.md)

#43 (PR #50) already ships the three per-item admin scripts in `home/dot_config/dotfiles/admin/`
(`enable-developer-mode.ps1`, `enable-ssh-agent.ps1`, `enable-wsl.ps1.tmpl`) and the user-side scripts that skip
with a one-line message when the machine part is missing (`run_once_before_install-wsl.ps1.tmpl`,
`run_once_after_add-ssh-key.ps1`). What is left: the aggregate script, the reminder at the end of apply, an easy way
for the user to run the per-user steps after the restart, and the docs. This spec turns the issue into requirements
and adds what the issue leaves open after reading the code (marked **[added]**).

## Decisions

### Confirmed in the issue (2026-11-18, revised in the PR #50 review 2026-11-20)

| # | Decision |
|---|---|
| C1 | chezmoi never runs an admin script; `chezmoi apply` stays admin-free |
| C2 | One script per item, plus one aggregate that runs the whole set |
| C3 | No elevation or identity check: a script assumes admin and fails with the system error otherwise |
| C4 | Idempotent and non-interactive: safe to rerun, safe to hand to someone else |
| C5 | A reminder at the end of apply checks **state, not elevation** |
| C6 | Admin scripts change only the machine and print the per-user step; they never run it (it would land in the administrator's profile) |
| C7 | PowerShell 7, no 5.1 compatibility, no BOM; run as `pwsh -NoProfile -ExecutionPolicy Bypass -File <path>` |
| C8 | No automatic elevation (UAC relaunch); no Windows containers / Hyper-V (#48); no retry of the user-side `run_once_` scripts |

### Confirmed for this spec (2026-11-22): D1–D6

| # | Question | Agreed | Why | Rejected alternative |
|---|---|---|---|---|
| D1 | Order in the aggregate | Developer Mode → ssh-agent → WSL | WSL is the only item that needs a restart and prints the longest output; last means its next steps are next to the recap | Alphabetical (WSL in the middle) |
| D2 | Failure in the aggregate | **Fail fast:** `$ErrorActionPreference = 'Stop'` in the aggregate; the item scripts are dot-sourced (`. "$PSScriptRoot\<name>.ps1"`), so they run in its scope and the first PowerShell error stops the run with exit code 1 and no recap. Native `wsl` exit codes are **not** checked | A non-admin run fails at the first HKLM write instead of printing three errors and a recap that reads like success. Native exit codes are unknown on a second run (Risks) and the repo does not check them | Continue and print an OK/FAILED summary (a result-tracking layer for three calls); `$PSNativeCommandUseErrorActionPreference` (would stop on a harmless non-zero `wsl` code) |
| D3 | Per-user steps in the aggregate's output | Each item keeps printing its own next step (needed when run alone); the aggregate ends with a short **recap**: restart, then `Complete-UserSetup` (D6) in a new PowerShell window | The person running it (IT) needs one short block to pass to the user, not steps scattered in `wsl --update` output | A `-NoNextSteps` switch on the three item scripts (a parameter in three files for a cosmetic gain) |
| D4 | What the reminder prints | **One message:** an administrator step is needed, with the one command to run `admin-setup.ps1`. No per-item list | Which item is on or off is the scripts' business: they are idempotent, so running the whole set is always correct | One line per missing item, plus the aggregate when two or more are missing |
| D5 | Reminder for the per-user steps (WSL distro, `ssh-add`) | **Rejected.** The reminder covers only the administrator step. After the `run_once_` user-side scripts have run, apply manages files and packages only; the per-user steps are printed by the admin scripts and described in the ReadMe | Apply does not nag about anything beyond its own scope | Probing `wsl -l -q` and `ssh-add -l` on every apply |
| D6 | How the user runs the per-user steps | A profile function **`Complete-UserSetup`** installs the WSL distro when missing and loads the SSH key. The admin scripts and the recap name the function instead of raw commands, so the aggregate and `enable-wsl.ps1` no longer need `packages.yaml` and stop being templates | One command to remember instead of two with flags; the distro name lives in one consumer | Raw `wsl --install …` / `ssh-add …` lines in each admin script |

## Requirements

### Aggregate (`home/dot_config/dotfiles/admin/admin-setup.ps1`)

- **R1** Deployed to `~/.config/dotfiles/admin/admin-setup.ps1` next to the three item scripts; never run by
  chezmoi; excluded on Linux by the existing `**/*.ps1` rule in `home/.chezmoiignore`. Not a template (D6).
- **R2** Sets `$ErrorActionPreference = 'Stop'` (D2), then dot-sources, in this order (D1), the item scripts from
  its own folder: `. "$PSScriptRoot\enable-developer-mode.ps1"`, `. "$PSScriptRoot\enable-ssh-agent.ps1"`,
  `. "$PSScriptRoot\enable-wsl.ps1"`. Works from any current directory; no `Set-Location`. Each item prints its own
  `► …` line and its own next step, which is "what each did".
- **R3** After the three, prints the recap (D3) with `Write-Host "► Next steps (as the user, not as administrator)"
  -ForegroundColor Yellow` and the lines `  1. Restart the computer.` and
  `  2. In a new PowerShell window: Complete-UserSetup`. The recap is not printed when an item fails (D2).
- **R4** The item scripts change only their next-step lines, which name `Complete-UserSetup` (D6):
  `enable-wsl` — restart, then as the user `Complete-UserSetup`; `enable-ssh-agent` — as the user
  `Complete-UserSetup`. `enable-wsl.ps1.tmpl` is renamed to `enable-wsl.ps1` (no template data left). Run alone they
  keep their behaviour (no `Stop` preference). `enable-developer-mode.ps1` is not changed.

### Per-user function (`home/dot_profile/user-setup_profile.ps1.tmpl`)

- **R13** Defines `Complete-UserSetup` (no parameters), loaded by the profile's glob over `~/.profile/*.ps1` (no
  profile edit). It:
  - **[added in review]** probes the machine part with the same tests as the skip scripts and skips a step with a
    Yellow one-line hint to run the administrator step when it is missing (`wsl --status` non-zero; ssh-agent not
    `Running`): without the platform, `wsl --install` would ask for elevation;
  - sets `$distro` from `.packages.windows.profiles.sdk.wsl` (rendered with `squote`) and `$env:WSL_UTF8 = '1'`
    (`wsl -l -q` is UTF-16 otherwise and `-contains` never matches), restoring the previous value afterwards because
    the function runs in the user's session;
  - when `(wsl -l -q) -contains $distro` is false, prints `► Installing WSL <distro>` (Cyan) and runs
    `wsl --install -d $distro --web-download --no-launch`;
  - prints `► Add ssh key` (Cyan) and runs `ssh-add (Join-Path $HOME '.ssh' 'id_ed25519')`.
  No admin; rerunning is safe (`ssh-add` re-adds the same key). The logic duplicates the two `run_once_` user-side
  scripts on purpose: those run before chezmoi deploys `~/.profile/`, so they cannot call the function.

### Reminder (`home/.chezmoiscripts/windows/run_after_zz-admin-reminder.ps1`)

- **R5** A plain `run_after_` script (runs on every apply, not `once`/`onchange`). **[added]** Its target name must
  sort **after** `yazi-plugins.ps1`, because after-phase scripts run in lexical order and digits sort before
  letters (`99-…` would run first). `zz-admin-reminder` is the name; checked with
  `chezmoi --source . managed --include=scripts`.
- **R6** Checks the three machine states with the **same** tests the skip scripts use, so the reminder and the
  skips never disagree; a comment above each probe says what it checks:
  - Developer Mode: DWORD `AllowDevelopmentWithoutDevLicense` under
    `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock` equals `1` (read with
    `-ErrorAction SilentlyContinue`; a standard user can read HKLM).
  - WSL: `wsl --status *> $null` exits `0` (as in `run_once_before_install-wsl.ps1.tmpl`).
  - ssh-agent: `(Get-Service ssh-agent -ErrorAction SilentlyContinue).Status -eq 'Running'` (as in
    `run_once_after_add-ssh-key.ps1`).
- **R7** When any of the three is missing, prints (D4):
  `Write-Host "► Administrator step needed" -ForegroundColor Yellow`, then
  `  Run as an administrator: pwsh -NoProfile -ExecutionPolicy Bypass -File "<path>"`, where `<path>` is
  **[added]** `Join-Path $HOME '.config\dotfiles\admin\admin-setup.ps1'` expanded at runtime and double-quoted (user
  names can contain spaces). An administrator elevating with their own account would resolve `~` or `$HOME` to their
  own profile, so the printed path must contain neither. The output does not say which item is missing.
- **R8** When all three are present, prints nothing.
- **R9** Never fails apply: no `Stop` preference, every probe with `-ErrorAction SilentlyContinue` or exit-code
  based, ends with `exit 0`. Never calls an admin script.

### Docs and tests

- **R10** `ReadMe.md`: a section "Administrator step (Windows)" — what needs admin and why (one sentence, link to
  ADR-0003); running `admin-setup.ps1` or a single script on a private machine; what to send IT on a managed one
  (the four files to review, since the aggregate dot-sources its siblings from a user-writable folder — ADR-0003
  *Consequences*; the absolute path, as the reminder prints it; do not run the per-user steps; restart); after the
  restart the user runs `Complete-UserSetup`; apply prints the reminder until the administrator step is done.
- **R11** `docs/packages.md`: drop "(the aggregate script and the reminder are #44)", mention the aggregate, the
  reminder and `Complete-UserSetup`, and list the function as the consumer of the `wsl` distro in place of the admin
  WSL script. `docs/architecture.md`: the admin row names `admin-setup.ps1`, the reminder and `Complete-UserSetup`.
  `docs/testing.md`: the host unit-test command includes `tests/windows/AdminSetup`.
- **R12** **[added]** Pester 6 tests in `tests/windows/AdminSetup/`, run on the host without admin and without
  running a real admin script: `Complete-UserSetup.Tests.ps1` (rendered fragment, mocked `wsl` / `ssh-add`),
  `Admin-Setup.Tests.ps1` (aggregate copied to `TestDrive:` with stub item scripts: order, recap, fail-fast) and
  `Admin-Reminder.Tests.ps1` (reminder with mocked probes: each item missing on its own, none missing, path form,
  exit 0).

## Non-goals

Windows containers / Hyper-V (#48); UAC relaunch; running the per-user steps from the admin session; retrying the
`run_once_` user-side scripts; reminding about the per-user steps (D5); provisioning the standard user in Vagrant
(#47); CI (#47).

## Acceptance

Mapping to the issue's criteria in brackets.

1. **Host:** every new or changed `.ps1` / `.ps1.tmpl` renders with `chezmoi --source . execute-template` and parses
   with zero errors; they are CRLF; `chezmoi --source . managed` lists `.config/dotfiles/admin/admin-setup.ps1`,
   `.config/dotfiles/admin/enable-wsl.ps1` and `.profile/user-setup_profile.ps1`; `managed --include=scripts` lists
   `zz-admin-reminder.ps1` last; Pester `tests/windows/AdminSetup` passes.
2. **Host:** the reminder run directly (`pwsh -NoProfile -File <reminder>`; read-only) prints the reminder exactly
   when at least one item is really missing on the host, and exits 0.
3. **VM, standard user:** `install.ps1` → apply exits 0 with no UAC prompt; the WSL/SSH scripts print their skip
   lines; the reminder names `admin-setup.ps1` with its absolute path under the user's profile;
   no script under `home/.chezmoiscripts/` invokes a file in `dotfiles\admin` (grep). [AC2, AC3 first half]
4. **VM, administrator account:** each item script run alone, then `admin-setup.ps1`, each twice; no errors; after
   the second run the state is the same (DWORD `1`; `ssh-agent` `Automatic` and `Running`; `wsl --status` exit 0
   after the restart). [AC1]
5. **VM, standard user after the restart:** runs `Complete-UserSetup` in a new PowerShell window without admin;
   `wsl -l -q` lists the distro; `ssh-add -l` lists the key; the next apply prints no reminder. [AC3 second half, AC4]
6. `ReadMe.md` and `docs/packages.md` describe the admin step and the per-user step. [AC5]

## Risks

- `wsl --status` exit code with WSL enabled but a restart pending is unverified (carried over from #43). If it is
  `0`, the reminder goes silent before the restart; if non-zero, the reminder keeps asking for `admin-setup.ps1`
  until the restart (harmless: idempotent). Also unverified: its exit code with the platform enabled but **no distro
  installed yet** (between the admin step and `Complete-UserSetup`); non-zero would make the reminder ask for the
  administrator step that is already done — and, worse, `Complete-UserSetup` and `run_once_before_install-wsl` (same
  probe, from #43) would never install the distro. Confirm both on the VM (Acceptance 4–5); if non-zero, switch the
  probe in all three places.
- Exit codes and output of `wsl --install --no-distribution` and `wsl --update` on a second run are unverified;
  `wsl --update` may download a newer WSL, which is not "changes nothing" in the strict sense. D2 does not check
  them, so they cannot fail the aggregate; Acceptance 4 records what they print.
- Admin scripts live in a user-writable folder (ADR-0003). The aggregate widens this to "whatever sits next to it
  under the three names"; IT must review all four files (R10).
- Pester mocking of the native `wsl` / `ssh-add` commands is assumed to work (a global stub function plus `Mock`);
  the first failing test run of Task 1 proves it before any implementation exists.
