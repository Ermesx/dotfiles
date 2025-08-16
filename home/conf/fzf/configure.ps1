# Copy fzf configuration file 
$configFile = '.fzfrc'
Copy-Item -Path "$PSScriptRoot\$configFile" -Destination "$HOME\$configFile" -Force 

$fzfDefaultCmd = '.fzfdc.cmd'
Copy-Item -Path "$PSScriptRoot\$fzfDefaultCmd" -Destination "$HOME\$fzfDefaultCmd" -Force
