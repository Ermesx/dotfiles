# Install or update zoxide
Install-OrUpdateApp -AppId ajeetdsouza.zoxide -UpdateEnv -Command "zoxide"

Add-ToProfile -Comment "Initialize zoxide" -ScriptBlock {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
} 