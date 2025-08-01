#Requires -Modules PSScriptAnalyzer

function Add-ToProfile {
<#
.SYNOPSIS
    Adds a script block to the PowerShell profile for future sessions.

.DESCRIPTION
    This function ensures the PowerShell profile exists and appends a specified script block to it. 
    The script block will be executed in all subsequent PowerShell sessions.

.PARAMETER Comment
    A description or comment to include above the script block in the profile.

.PARAMETER Script
    The script block to append to the PowerShell profile.

.EXAMPLE
    Add-ToProfile -Comment "Initialize MyFunction" -ScriptBlock { MyFunction }

    Adds a comment and the "MyFunction" script block to the PowerShell profile.
#>
    [CmdletBinding()]
    param (
        [string]$Comment,
        [string]$Path,
        [switch]$Pwsh5,
        [scriptblock]$ScriptBlock
    )
    
    # Check parameters
    if (-not $Path -and -not $ScriptBlock)
    {
        throw "❌ You must provide at least one parameter: -Path or -ScriptBlock."
    }

    function Write-Profile {
        param (
            [string]$ProfilePath
        )
    
        # Ensure the profile directory exists
        if (-not (Test-Path $ProfilePath)) {
            New-Item -Path $ProfilePath -ItemType File -Force | Out-Null
            Write-Host "📄 Created PowerShell profile at $ProfilePath" -ForegroundColor Green
        }
    
        # Add the script block or path to the profile
        if ($Comment){
            Add-Content -Path $ProfilePath -Value "# $Comment"
        }
    
        if ($ScriptBlock) {
            $ScriptBlock.ToString().Trim() | Invoke-Formatter | Add-Content -Path $ProfilePath 
        }
    
        if ($Path) {
            Get-Content -Path $Path -Raw | Invoke-Formatter | Add-Content -Path $ProfilePath
        }
    
        Add-Content -Path $ProfilePath -Value "`n"
    }

    # Define the destination path in the user module directory
    $profileFile = "Microsoft.PowerShell_profile.ps1"
    $pwsh5ProfilePath = Join-Path -Path "~\Documents\WindowsPowerShell" -ChildPath $profileFile
    $pwsh7ProfilePath = Join-Path -Path "~\Documents\PowerShell" -ChildPath $profileFile
    
    # Ensure the PowerShell profile exists
    Write-Profile -ProfilePath $pwsh7ProfilePath
    if ($Pwsh5) { Write-Profile -ProfilePath $pwsh5ProfilePath }

    Write-Host "==> ● "-NoNewline
    Write-Host "Added script block to PowerShell profile: " -ForegroundColor DarkGray -NoNewline
    Write-Host "$Comment" -ForegroundColor Cyan
}