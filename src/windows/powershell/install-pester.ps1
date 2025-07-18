# Install or update Pester module in PowerShell
Install-OrUpdateModule -ModuleName Pester -Force

Add-ToProfile -Comment "Import Pester" -ScriptBlock {
    Import-Module Pester
} 