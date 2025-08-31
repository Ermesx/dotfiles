$env:FZF_DEFAULT_OPTS_FILE = Join-Path $HOME ".config\fzf\.fzfrc"
$env:FZF_DEFAULT_COMMAND = Get-Content -Path (Join-Path $HOME ".config\fzf\.fzfdc")
$env:_PSFZF_FZF_DEFAULT_OPTS = Get-Content -Path (Join-Path $HOME ".config\fzf\.psfzfrc") 

Set-PsFzfOption -TabExpansion
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' `
                -PSReadlineChordReverseHistory 'Ctrl+h'
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion } -BriefDescription "Run fzf Tab completion"
