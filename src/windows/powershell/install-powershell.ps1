# Install or upgrade Dotfiles-Toolkit if not already installed
. "$PSScriptRoot\Dotfiles-Toolkit\functions\Install-LocalModule.ps1"
Install-LocalModule -SourceModulePath "$PSScriptRoot\Dotfiles-Toolkit"
Import-Module Dotfiles-Toolkit -Force

# Clear the PowerShell profile to avoid duplicates
Clear-Profile -All

Add-ToProfile -Comment "Import Dotfiles-Toolkit" -Pwsh5 -ScriptBlock {
    Import-Module Dotfiles-Toolkit
}

# Trust the PSGallery repository
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

# Install or upgrade winget client
Install-OrUpdateModule -ModuleName Microsoft.WinGet.Client
Import-Module Microsoft.WinGet.Client
Repair-WinGetPackageManager -Latest

Add-ToProfile -Comment "Import Microsoft.WinGet.Client" -Pwsh5 -ScriptBlock {
    Import-Module Microsoft.WinGet.Client
}

# Install or upgrade PowerShell
Install-OrUpdateApp -AppId Microsoft.Powershell -UpdateEnv -Command "pwsh"

Add-ToProfile -Comment "Configure PSReadLine" `
              -Path "$PSScriptRoot\configure-PSReadLine.ps1"
