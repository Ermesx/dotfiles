function Clear-Profile {
<#
.SYNOPSIS
    Clears the PowerShell profile.

.DESCRIPTION
    This function clears the PowerShell profile by removing all content from the profile file.
    It is useful for resetting the profile to a clean state.

.EXAMPLE
    Clear-Profile

    Clears the PowerShell profile.
#>
    [CmdletBinding()]
    param ()

    # Define the destination path in the user module directory
    $profileFile = "Microsoft.PowerShell_profile.ps1"
    $pwsh5ProfilePath = Join-Path -Path "$HOME\Documents\WindowsPowerShell" -ChildPath $profileFile
    $pwsh7ProfilePath = Join-Path -Path "$HOME\Documents\PowerShell" -ChildPath $profileFile

    try {
        if ((Test-Path $pwsh5ProfilePath) -and (Test-Path $pwsh7ProfilePath)) {
            Clear-Content -Path $pwsh5ProfilePath
            Clear-Content -Path $pwsh7ProfilePath
            Write-Host "📄 Profiles cleared: `n`t$pwsh5ProfilePath `n`t$pwsh7ProfilePath"
        } else {
            Write-Host "❌ Profile does not exist: `n`t$pwsh5ProfilePath `n`t$pwsh7ProfilePath"
        }
    } catch [System.IO.IOException] {
        Write-Host "❌ Unable to clear profile. The file might be open or locked: `n`t$pwsh5ProfilePath `n`t$pwsh7ProfilePath"
    }
}