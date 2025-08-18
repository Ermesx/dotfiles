$env:FZF_DEFAULT_OPTS_FILE = Join-Path $HOME \.fzf\.fzfrc"
$env:FZF_DEFAULT_COMMAND = Get-Content "$HOME\.fzf\.fzfdc.cmd"