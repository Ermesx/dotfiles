#Requires -Modules PSScriptAnalyzer

function Add-ToProfile {
<#
.SYNOPSIS
    Adds a script block to the PowerShell profile for future sessions.

.DESCRIPTION
    This function ensures the PowerShell profile exists and appends a specified script block to it. 
    The script block will be executed in all subsequent PowerShell sessions for the specified PowerShell version.

.PARAMETER Comment
    A description or comment to include above the script block in the profile.

.PARAMETER Path
    The path to a script file to add to the profile.

.PARAMETER ScriptBlock
    The script block to append to the PowerShell profile.

.PARAMETER Version
    The PowerShell version to add the content to. Valid values are 5 (Windows PowerShell) or 7 (PowerShell Core). Defaults to 7.

.EXAMPLE
    Add-ToProfile -Comment "Initialize MyFunction" -ScriptBlock { MyFunction }

    Adds a comment and the "MyFunction" script block to the PowerShell 7 profile.

.EXAMPLE
    Add-ToProfile -Path "C:\Scripts\MyScript.ps1" -Version 5

    Adds the content of MyScript.ps1 to the Windows PowerShell profile.

.EXAMPLE
    Add-ToProfile -Comment "Custom Configuration" -ScriptBlock { Set-Location C:\ } -Version 7

    Adds a custom configuration to the PowerShell 7 profile.
#>
    [CmdletBinding()]
    param (
        [string]$Comment,
        [string]$Path,
        [scriptblock]$ScriptBlock,
        [ValidateSet(5, 7)]
        [int]$Version = 7
    )
    
    # Check parameters
    if (-not $Path -and -not $ScriptBlock)
    {
        throw "❌ You must provide at least one parameter: -Path or -ScriptBlock."
    }

    # Define the destination path in the user module directory
    $profileFile = "Microsoft.PowerShell_profile.ps1"
    $profilePath = if ($version -eq 7) { '~\Documents\PowerShell' } else { '~\Documents\WindowsPowerShell' }
    $profilePathFile = Join-Path -Path $profilePath -ChildPath $profileFile

    # Ensure the profile directory exists
    if (-not (Test-Path $profilePathFile)) {
        New-Item -Path $profilePathFile -ItemType File -Force | Out-Null
        Write-Host "📄 Created PowerShell profile at $profilePathFile" -ForegroundColor Green
    }
    
    # Add the script block or path to the profile
    if ($Comment){
        Add-Content -Path $profilePathFile -Value "# $Comment"
    }
    
    if ($ScriptBlock) {
        $ScriptBlock.ToString().Trim() | Invoke-Formatter | Add-Content -Path $profilePathFile
    }
    
    if ($Path) {
        Get-Content -Path $Path -Raw | Invoke-Formatter | Add-Content -Path $profilePathFile
    }
    
    Add-Content -Path $profilePathFile -Value "`n"

    Write-Host "==> "-NoNewline
    Write-Green "● "-NoNewline
    Write-Host "Added to pwsh profile: " -ForegroundColor DarkGray -NoNewline
    Write-Host "$Comment" -ForegroundColor Cyan
}