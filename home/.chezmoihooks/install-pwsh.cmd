@echo off

where /q pwsh
if errorlevel 1 (
    echo "Installing PowerShell 7..."
    winget install --id Microsoft.PowerShell --exact --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
)

exit 0