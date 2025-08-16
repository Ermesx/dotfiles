# Run tests after the installation script
$testPath = Join-Path -Path $PSScriptRoot -ChildPath "windows"
Invoke-Pester -Path $testPath -Output Detailed
