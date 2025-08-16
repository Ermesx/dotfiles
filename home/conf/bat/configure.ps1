# Copy configuration
$targetPath = (bat --config-file)
Copy-Item -Path "$PSScriptRoot\config" -Destination "$targetPath" -Force
