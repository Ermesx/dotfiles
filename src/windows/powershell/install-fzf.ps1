# Install or update fzf
Install-OrUpdateApp -AppId junegunn.fzf -UpdateEnv -Command "fzf"

Install-OrUpdateModule -ModuleName PSfzf

Add-ToProfile -Comment "Initialize fzf key bindings" -ScriptBlock {
    Import-Module PSfzf
    Set-PsFzfOption -TabExpansion
    Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
    
    # TODO: add fzf configuration to improve preview and other features
}