# Minimal import from dotfiles-toolkit to install local modules 

# Internal pad lenght
. "$PSScriptRoot\private\Get-PadLength.ps1"

# Colored messages
. "$PSScriptRoot\public\Write-Pretty.ps1"
. "$PSScriptRoot\public\Write-Pretty.Colors.ps1"

# Local module installation script
. "$PSScriptRoot\public\Install-LocalModule.ps1"