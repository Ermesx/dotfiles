$ErrorActionPreference = "Stop"

#region Helper Functions

function Add-ImportModulesToProfile {
    param ( [string[]]$modules )
    
    $importLines = $modules | ForEach-Object { "Import-Module '$_'" }
    $importScript = [ScriptBlock]::Create(($importLines -join "`n"))

    # Omit communicating simple module import in the profile
    Add-ToProfile -Comment 'Import modules' -ScriptBlock $importScript 6> $null
}

function Add-ConfigToProfile {
    param ( [System.IO.FileInfo[]]$files )
    
    foreach ($file in $files) {
        $featureName = Split-Path $file -Parent
        Add-ToProfile -Comment "Load configuration from $featureName" -Path $file.FullName

        Write-Host "==> "-NoNewline
        Write-Green "● "-NoNewline
        Write-Host "Added to pwsh profile: " -ForegroundColor DarkGray -NoNewline
        Write-Host "$Comment" -ForegroundColor Cyan
    }
}

function Invoke-Configurations {
    Get-ChildItem -Recurse $PSScriptRoot -Filter 'configure.ps1' | ForEach-Object { & $_.FullName }
}

#endregion



# Installing... !!
Write-Host "⚙️ Installing dotfiles on Windows..."

#region Setup scripts
Write-Host "`n=== === === === ==>" -NoNewline
Write-Cyan "     🔧 Setup...    " -NoNewline
Write-Host "<== === === === ==="




#region Install scripts





#endregion

#region Post-install scripts
Write-Host "`n=== === === === ==>" -NoNewline
Write-Cyan "   🔧 Configure...  " -NoNewline
Write-Host "<== === === === ==="


 
# Add module imports to the PowerShell profile
Add-ImportModulesToProfile @(
    @('Dotfiles-Toolkit') +
    $requiredModules +
    $packages.modules
)

Invoke-Configurations

$profiles = Get-ChildItem -Recurse $PSScriptRoot -Filter 'profile.ps1'
Add-ConfigToProfile $profiles

# TODO: add wsl install and upgrade

#endregion