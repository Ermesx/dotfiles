param (
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Config
)


Add-ToProfile -Comment "Initialize zoxide" -ScriptBlock {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

Copy-Item -Path $Config.bat.configPath -Destination (bat --config-file) -Force


Copy-Item -Path $Config.rg.configPath -Destination "~\" -Force
$rgFileName = Split-Path -Path $Config.rg.configPath -Leaf

Add-ToProfile -Comment "Initialize ripgrep" -ScriptBlock (
    Update-ScriptBlock -ScriptBlockTemplate {
        $env:RIPGREP_CONFIG_PATH = "{{filePath}}"
    } -Values @{ filePath = Join-Path $HOME $rgFileName }
)


Copy-Item -Path $Config.fzf.configPath -Destination "~\" -Force
$fzfFileName = Split-Path -Path $Config.fzf.configPath -Leaf


Add-ToProfile -Comment "Initialize fzf key bindings" -ScriptBlock (
    Update-ScriptBlock -ScriptBlockTemplate {
        Set-PsFzfOption -TabExpansion
        Set-PsFzfOption -PSReadlineChordProvider '{{defaults.binding.searchKey}}' `
                        -PSReadlineChordReverseHistory '{{defaults.binding.historyKey}}'
        Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion } -BriefDescription "Run fzf Tab completion"
        
        $env:FZF_DEFAULT_OPTS_FILE = "{{filePath}}"
        $env:FZF_DEFAULT_COMMAND = "{{defaults.defaultCommand}}"
        $env:_PSFZF_FZF_DEFAULT_OPTS = "{{defaults.psfzfOpts}}"
    } -Values @{
        defaults = $Config.fzf.defaults
        filePath = Join-Path $HOME $fzfFileName
    }
)


#TODO: dodać wyszukiwanie plików, directories i commands - wzorować się na artykule, zainstalować fd, esa i ripgrep, dodać wyszukiwanie w plikach
