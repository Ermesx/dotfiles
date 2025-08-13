# Symlink rg configuration
$configFile = '.rgrc'
New-item -ItemType SymbolicLink -Target "$PSScriptRoot\$configFile" `
                                -Path   "$HOME\$configFile" -Force 