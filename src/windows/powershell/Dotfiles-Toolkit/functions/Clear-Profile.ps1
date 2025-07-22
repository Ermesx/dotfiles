function Clear-Profile {
<#
.SYNOPSIS
    Clears the PowerShell profile by removing its content.

.DESCRIPTION
    This function clears the PowerShell profile by removing all content from the profile file.
    It is useful for resetting the profile to a clean state. If the `-All` switch is used, 
    it clears profiles for both Windows PowerShell and PowerShell 7.

.PARAMETER All
    Clears profiles for both Windows PowerShell and PowerShell 7.

.EXAMPLE
    Clear-Profile

    Clears the PowerShell 7 profile.

.EXAMPLE
    Clear-Profile -All

    Clears both Windows PowerShell and PowerShell 7 profiles.
#>
    [CmdletBinding()]
    param (
        [switch]$All
    )

    function Clear-Profile-Path {
        param (
            [string]$ProfilePath
        )

        # Ensure the profile directory exists
        try {
            if (Test-Path $ProfilePath) {
                Clear-Content -Path $ProfilePath | Out-Null
                Write-Host "📄 Profile cleared: $ProfilePath"
            } else {
                Write-Host "❌ Profile does not exist: $ProfilePath"
            }
        } catch [System.IO.IOException] {
            Write-Host "❌ Unable to clear profile. The file might be open or locked: $ProfilePath"
        }
    }

    # Define the destination path in the user module directory
    $profileFile = "Microsoft.PowerShell_profile.ps1"
    $pwsh5ProfilePath = Join-Path -Path "~\Documents\WindowsPowerShell" -ChildPath $profileFile
    $pwsh7ProfilePath = Join-Path -Path "~\Documents\PowerShell" -ChildPath $profileFile

    Clear-Profile-Path -ProfilePath $pwsh7ProfilePath
    if ($All) { Clear-Profile-Path -ProfilePath $pwsh5ProfilePath }
}