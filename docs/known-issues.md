# Known issues (as of 2026-10-14)

Problems found in the code while writing `AGENTS.md`. Not fixed yet; the owner will address them later.

- `tests/windows/Installed-Apps-Modules.Tests.ps1` selects modules by type `AnyPackageDsc/Package`, but the DSC
  template emits `PowerShellModule/PSModuleResource`, so the *Modules* context discovers zero test cases.
- `run_once_after-yazi-plugins.ps1.tmpl` runs `ya pkg add` only when the plugin **is** already listed
  (`-like` instead of `-notlike`), so plugins are never installed on a fresh machine.
- Linux support is incomplete: `packages.linux.*` (brews, casks, modules) is not consumed by any template, there
  is no `install.sh` in the repo (ReadMe links to an external one), and `tests/run-tests.sh` has no real tests.
- Three scripts use a dash instead of an underscore after the phase (`run_once_before-install-font`,
  `run_once_after-add-ssh-key`, `run_once_after-yazi-plugins`), so chezmoi gives them no phase. They run during
  file application in lexical order. `.chezmoiscripts/` sorts before `.ssh/`, so on a fresh machine `add-ssh-key`
  most likely runs **before** `~/.ssh/id_ed25519` is written (not verified on a clean VM). The font script used to
  be `run_once_before_02-install-font`, so this looks like a regression.
- `ReadMe.md` package table is stale: it lists .NET SDK 9 and `file (GnuWin32.File)`, which is no longer installed,
  and it misses jq, AIChat, GitHub CLI, Node.js, Vagrant, Scalar, and refitter.
- Write-Pretty tests: 3 of 8 fail under Pester 5.7.1 against the working copy. Every `Write-PrettyTable` case
  (pipeline objects, array argument, hashtable pipeline) reports `Write-Host` called 0 times. Likely cause (unverified):
  tests and function drifted apart after the pipeline-input change (commit 2fdc319). Under Pester 6.1 all 8 fail on load (`Assert-MockCalled`).
