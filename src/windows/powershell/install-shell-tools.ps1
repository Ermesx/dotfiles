param (
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Config
)

# Install or update Zoxide for fast directory navigation
Install-OrUpdateApp -AppId ajeetdsouza.zoxide -UpdateEnv -Command "zoxide"

Add-ToProfile -Comment "Initialize zoxide" -ScriptBlock {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# Install GnuWin32.File type checker
Install-OrUpdateApp -AppId GnuWin32.File -UpdateEnv -Command "file" -AdditionalEnvPath "C:\Program Files (x86)\GnuWin32\bin"

# Install or update Bat and configure
Install-OrUpdateApp -AppId sharkdp.bat -UpdateEnv -Command "bat"
Copy-Item -Path $Config.bat.configPath -Destination (bat --config-file) -Force

# Install or update fd fast file search tool
Install-OrUpdateApp -AppId sharkdp.fd -UpdateEnv -Command "fd"

# Install or update ripgrep for searching within files
Install-OrUpdateApp -AppId BurntSushi.ripgrep.MSVC -UpdateEnv -Command "rg"
Copy-Item -Path $Config.rg.configPath -Destination "~\" -Force
$rgFileName = Split-Path -Path $Config.rg.configPath -Leaf

Add-ToProfile -Comment "Initialize ripgrep" -ScriptBlock (
    Update-ScriptBlock -ScriptBlockTemplate {
        $env:RIPGREP_CONFIG_PATH = "{{filePath}}"
    } -Values @{ filePath = Join-Path $HOME $rgFileName }
)

# Install or update eza modern ls replacement
Install-OrUpdateApp -AppId eza-community.eza -UpdateEnv -Command "eza"

# Install or update fzf (fuzzy finder)
Install-OrUpdateApp -AppId junegunn.fzf -UpdateEnv -Command "fzf"

Copy-Item -Path $Config.fzf.configPath -Destination "~\" -Force
$fzfFileName = Split-Path -Path $Config.fzf.configPath -Leaf

# Install or update PSfzf module & configure fzf
Install-OrUpdateModule -ModuleName PSfzf

Add-ToProfile -Comment "Initialize fzf key bindings" -ScriptBlock (
    Update-ScriptBlock -ScriptBlockTemplate {
        Import-Module PSfzf
        Set-PsFzfOption -TabExpansion
        Set-PsFzfOption -PSReadlineChordProvider '{{searchKey}}' -PSReadlineChordReverseHistory '{{historyKey}}'
        Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion } -BriefDescription "Run fzf Tab completion"
        $env:FZF_DEFAULT_OPTS_FILE = "{{filePath}}"
        $env:FZF_DEFAULT_COMMAND = "{{defaultCommand}}"
        $env:_PSFZF_FZF_DEFAULT_OPTS = "{{psfzfOpts}}"
    } -Values @{
        searchKey = $Config.fzf.defaults.binding.searchKey
        historyKey = $Config.fzf.defaults.binding.historyKey
        filePath = Join-Path $HOME $fzfFileName
        defaultCommand = $Config.fzf.defaults.defaultCommand
        psfzfOpts = $Config.fzf.defaults.psfzfOpts
    }
)


#TODO: dodać wyszukiwanie plików, directories i commands - wzorować się na artykule, zainstalować fd, esa i ripgrep, dodać wyszukiwanie w plikach

#export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'