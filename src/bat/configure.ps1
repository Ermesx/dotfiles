# Symlink configuration
$targetPath = bat --config-file
New-item -ItemType SymbolicLink -Target "$PSScriptRoot\config" `
                                -Path   $targetPath -Force 