param (
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$FzfConfigFile
)

# Install or update fzf
Install-OrUpdateApp -AppId junegunn.fzf -UpdateEnv -Command "fzf"

Copy-Item -Path $FzfConfigFile -Destination "~\" -Force
$filename = Split-Path -Path $FzfConfigFile -Leaf

# Install or update PSfzf module & configure
Install-OrUpdateModule -ModuleName PSfzf

$script = Update-ScriptBlock -ScriptBlockTemplate {
    Import-Module PSfzf
    Set-PsFzfOption -TabExpansion
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
    $env:FZF_DEFAULT_OPTS_FILE = "{{filePath}}"
} -Values @{ filePath = Join-Path $HOME $filename }

Add-ToProfile -Comment "Initialize fzf key bindings" -ScriptBlock $script

# Install GnuWin32.File
Install-OrUpdateApp -AppId "GnuWin32.File" -UpdateEnv -Command "file" -AdditionalEnvPath "C:\Program Files (x86)\GnuWin32\bin"

# $env:FZF_DEFAULT_COMMAND = "fd --type f --hidden --exclude .git" - zainstalować pozostałe toole
# sPSFZF ma tylko $env:_PSFZF_FZF_DEFAULT_OPTS - można dać np. --height 50% 
