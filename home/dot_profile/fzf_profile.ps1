$env:FZF_DEFAULT_OPTS_FILE = Join-Path $HOME ".fzf\.fzfrc"
$env:FZF_DEFAULT_COMMAND = Join-Path $HOME ".fzf\.fzfdc" | Get-Content
$env:_PSFZF_FZF_DEFAULT_OPTS = Join-Path $HOME ".fzf\.psfzfrc" | Get-Content

Set-PsFzfOption -TabExpansion
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' `
                -PSReadlineChordReverseHistory 'Ctrl+h'
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion } -BriefDescription "Run fzf Tab completion"
