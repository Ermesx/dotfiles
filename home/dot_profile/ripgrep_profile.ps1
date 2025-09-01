# Initialize the ripgrep config env variable
$env:RIPGREP_CONFIG_PATH = Join-Path $HOME ".config\.rgrc"

# Initializes rg completion
Invoke-Expression (& { (rg --generate complete-powershell | out-string) })