# Testing

- The full install is tested only in the Vagrant VM. Only the Windows VM has a test runner.
- Inside the VM, `run-tests.ps1` downloads only `install.ps1` from GitHub (`.../refs/heads/<branch>/install.ps1`),
  so push changes to `install.ps1` before testing them.
- Dotfile content comes from your **local working copy**: the Vagrantfile syncs the repo root into the VM's chezmoi
  source dir, and `chezmoi init` skips cloning when that dir is already a git repo.
- Tests under `tests/windows/` that check a completed install (they read `~/.config/config.dsc.yaml`) run only in
  the VM.
