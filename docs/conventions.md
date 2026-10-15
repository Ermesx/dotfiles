# Conventions

## Line endings and formatting

`.editorconfig` is the authority; `.gitattributes` matches it.

- `*.ps1`, `*.bat`, `*.cmd`: **CRLF**.
- Everything else, including `*.ps1.tmpl`, `*.psm1`, and `*.psd1`: **LF**.
- Indent and other formatting rules: follow `.editorconfig`.

## Scripts

- Scripts must be idempotent: guard every install with an existence check (existing scripts show the pattern).
- User-facing progress lines use `Write-Host "► <Action>" -ForegroundColor Cyan`.

## PowerShell profile

The profile imports every module from `packages.windows.modules`, then dot-sources every `~/.profile/*.ps1` by glob
at apply time. A new fragment in `home/dot_profile/` needs no profile edit.
