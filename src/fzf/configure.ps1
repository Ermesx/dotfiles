# Symlink fzf configuration file 
$configFile = '.fzfrc'
New-item -ItemType SymbolicLink -Target "$PSScriptRoot\$configFile" `
                                -Path   "$HOME\$configFile" -Force 

$fzfDefaultCmd = '.fzfdc.cmd'
New-item -ItemType SymbolicLink -Target "$PSScriptRoot\$fzfDefaultCmd" `
                                -Path   "$HOME\$fzfDefaultCmd" -Force 

