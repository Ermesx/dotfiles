Set-PsFzfOption -TabExpansion `
                -GitKeyBindings `
                -EnableFd `
                -PSReadlineChordProvider 'Ctrl+t' `
                -PSReadlineChordReverseHistory 'Ctrl+r' `
                -PSReadlineChordSetLocation 'Alt+c' `
                -AltCCommand { param($Location) z $Location }
                
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion } -BriefDescription "Run fzf Tab completion"
