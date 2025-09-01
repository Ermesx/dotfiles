# Update the PATH environment variable to make sure all installed programs are accessible
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
$env:PATH = "$userPath;$machinePath"

# Run tests after the installation script
$testPath = Join-Path -Path $PSScriptRoot -ChildPath "windows"
Invoke-Pester -Path $testPath -Output Detailed
