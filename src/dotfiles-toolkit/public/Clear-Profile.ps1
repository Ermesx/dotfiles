function Clear-Profile {
<#
.SYNOPSIS
    Clears the PowerShell profile by removing its content.

.DESCRIPTION
    This function clears the PowerShell profile by removing all content from the profile file.
    It is useful for resetting the profile to a clean state for the specified PowerShell version.

.PARAMETER Version
    The PowerShell version to clear the profile for. Valid values are 5 (Windows PowerShell) or 7 (PowerShell Core). Defaults to 7.

.EXAMPLE
    Clear-Profile

    Clears the PowerShell 7 profile.

.EXAMPLE
    Clear-Profile -Version 5

    Clears the Windows PowerShell profile.

.EXAMPLE
    Clear-Profile -Version 7

    Clears the PowerShell 7 profile.
#>
    [CmdletBinding()]
    param (
        [ValidateSet(5, 7)]
        [int]$Version = 7
    )

    # Define the destination path in the user module directory
    $profileFile = "Microsoft.PowerShell_profile.ps1"
    $profilePath = if ($version -eq 7) { '~\Documents\PowerShell' } else { '~\Documents\WindowsPowerShell' }
    $profilePathFile = Join-Path -Path $profilePath -ChildPath $profileFile

    try {
        if (Test-Path $profilePathFile) {
            Clear-Content -Path $profilePathFile | Out-Null
            Write-Host "📄 Profile cleared: $profilePathFile"
        } else {
            Write-Host "❌ Profile does not exist: $profilePathFile"
        }
    } catch [System.IO.IOException] {
        Write-Host "❌ Unable to clear profile. The file might be open or locked: $profilePathFile"
    }
}