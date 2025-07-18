# Install or update fzf
Install-OrUpdateApp -AppId junegunn.fzf -UpdateEnv -Command "fzf"

Install-OrUpdateModule -ModuleName PSfzf

Add-ToProfile -Comment "Initialize fzf key bindings" -ScriptBlock {
    
    Import-Module PSfzf
    # TODO: change configuration to use PSfzf module
    
    Set-PSReadLineKeyHandler -Key "Ctrl+h" -ScriptBlock {
        $selection = (Get-History | Sort-Object -Descending Id | Select-Object -ExpandProperty CommandLine | fzf)
        if ($selection) { [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selection) }
    }
}