param (
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$BatConfigFile
)

# Install or update Bat
Install-OrUpdateApp -AppId "sharkdp.bat" -UpdateEnv -Command "bat"

# Add Bat configuration
Copy-Item -Path $BatConfigFile -Destination (bat --config-file) -Force