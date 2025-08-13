# Initialize PSFzf
Set-PsFzfOption -TabExpansion
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' `
                -PSReadlineChordReverseHistory 'Ctrl+h'
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion } -BriefDescription "Run fzf Tab completion"

$env:_PSFZF_FZF_DEFAULT_OPTS = '--style default --height 50%'