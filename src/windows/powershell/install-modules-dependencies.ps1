# Install or update Pester module in PowerShell
Install-OrUpdateModule -ModuleName Pester

# Install or update PSScriptAnalyzer module in PowerShell
Install-OrUpdateModule -ModuleName PSScriptAnalyzer

# Install or update PSMustache
Install-OrUpdateModule -ModuleName PSMustache

$importScript = {
    Import-Module Pester
    Import-Module PSScriptAnalyzer
    Import-Module PSMustache
}

Add-ToProfile -Comment "Import Basic Modules" -ScriptBlock $importScript

# Import the script to ensure modules are loaded in the current session
& $importScript

