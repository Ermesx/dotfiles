# Symlink rg configuration
$configFile = '.rgrc'
Copy-Item -Path  "$PSScriptRoot\$configFile" -Destination "$HOME\$configFile" -Force 