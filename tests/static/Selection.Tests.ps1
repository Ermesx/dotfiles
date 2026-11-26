#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The selection asked at `chezmoi init` (home/.chezmoi.toml.tmpl): profiles, picks and offered items stored under [data].
# Runs a real `chezmoi init` (execute-template has no --prompt) with a temp config and destination: no apply, nothing touches the home.
BeforeAll {
    $root = (Resolve-Path "$PSScriptRoot/../..").Path

    # Labels of a profile as packages.yaml declares them (item without the bucket)
    $data = (& chezmoi --source $root data --format json | ConvertFrom-Json)
    function Get-Label([string]$Profile) {
        $definitions = @($data.packages.global.profiles.$Profile, $data.packages.($data.chezmoi.os).profiles.$Profile) | Where-Object { $_ }
        @($definitions | ForEach-Object { $_.PSObject.Properties } | Where-Object { $_.Name -notin 'pick', 'wsl' } |
            ForEach-Object { $_.Value } | ForEach-Object { ($_ -split '/')[-1] })
    }
    function ConvertTo-TomlList([string[]]$Labels) { ($Labels | ForEach-Object { '"' + $_ + '"' }) -join ',' }
    $aiLabels = Get-Label 'ai'
    $aiList = ConvertTo-TomlList $aiLabels
    $appsLabels = Get-Label 'apps'

    # $Existing is the config already on the machine; Output is the config init wrote
    function Invoke-InitTemplate([hashtable]$Env = @{}, [string[]]$Flags = @(), [string]$Existing = '') {
        $config = Join-Path $TestDrive "$([guid]::NewGuid()).toml"
        Set-Content -Path $config -Value $Existing
        $names = @('DOTFILES_PROFILES') + @(Get-ChildItem Env: | Where-Object Name -like 'DOTFILES_PICKS_*' | ForEach-Object Name) + @($Env.Keys)
        $saved = @{}
        foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
        try {
            foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $null) }
            foreach ($name in $Env.Keys) { [Environment]::SetEnvironmentVariable($name, $Env[$name]) }
            $all = & chezmoi --source $root --config $config --destination (Join-Path $TestDrive 'home') init --no-tty @Flags 2>&1
            $exitCode = $LASTEXITCODE
        } finally {
            foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
        }
        $isError = { $_ -is [System.Management.Automation.ErrorRecord] }
        [pscustomobject]@{
            Config   = $config
            Output   = (Get-Content -Raw $config)
            Error    = ($all | Where-Object $isError | ForEach-Object { "$_" }) -join "`n"
            ExitCode = $exitCode
        }
    }

    # The view's pending items as the written config makes them
    function Get-Pending([string]$Config) {
        $template = '{{ (includeTemplate "packages.tmpl" . | fromJson).pending | toJson }}'
        & chezmoi --source $root --config $Config execute-template $template | ConvertFrom-Json
    }

    # A machine that chose rider out of apps when only rider existed: the other apps items are new since
    # (TOML allows indented keys; only the closing '@ of a here-string must stay at column 0)
    $narrowOffer = @'
    [data]
    profiles = ["apps"]
    [data.picks]
    apps = ["rider"]
    [data.offered]
    apps = ["rider"]
'@
}

Describe 'selection at init' {

    It 'takes profiles from DOTFILES_PROFILES' {
        $result = Invoke-InitTemplate -Env @{ DOTFILES_PROFILES = 'shell,sdk' }

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'profiles = \[("shell", ?"sdk"|"sdk", ?"shell")\]'
        $result.Output | Should -Not -Match 'profiles = .*apps'
    }

    It 'treats base alone as only base' {
        $result = Invoke-InitTemplate -Env @{ DOTFILES_PROFILES = 'base' }

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'profiles = \[\]'
    }

    It 'fails on an unknown profile in DOTFILES_PROFILES' {
        $result = Invoke-InitTemplate -Env @{ DOTFILES_PROFILES = 'shel' }

        $result.ExitCode | Should -Not -Be 0
        $result.Error | Should -Match 'shel'
        $result.Error | Should -Match 'choose from .*shell'
    }

    It 'takes picks from DOTFILES_PICKS_AI' {
        $result = Invoke-InitTemplate -Env @{ DOTFILES_PROFILES = 'ai'; DOTFILES_PICKS_AI = 'claude-code' }

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match '(?s)\[data\.picks\]\s+ai = \["claude-code"\]'
    }

    It 'takes every pick when DOTFILES_PROFILES is set without DOTFILES_PICKS' {
        # A stored answer makes the test discriminating: a prompt would return it, the environment mode must not
        $existing = @'
        [data]
        profiles = ["apps"]
        [data.picks]
        apps = ["rider"]
        [data.offered]
        apps = ["vscode", "rider", "googlechrome", "postman", "vagrant"]
'@
        $result = Invoke-InitTemplate -Env @{ DOTFILES_PROFILES = 'apps' } -Existing $existing

        $result.ExitCode | Should -Be 0
        foreach ($label in 'rider', 'googlechrome', 'postman', 'vagrant') {
            $result.Output | Should -Match "(?s)\[data\.picks\]\s+apps = \[[^\]]*`"$label`""
        }
    }

    It 'selects everything with no stored answer' {
        $result = Invoke-InitTemplate -Flags '--prompt', '--promptDefaults'

        $result.ExitCode | Should -Be 0
        $aiLabels | Should -Contain 'claude-code'
        foreach ($name in 'ai', 'apps', 'containers', 'sdk', 'shell') {
            $result.Output | Should -Match "profiles = \[[^\]]*`"$name`""
        }
        $result.Output | Should -Match "(?s)\[data\.picks\]\s+ai = \[$([regex]::Escape($aiList))\]\s+apps = \[[^\]]*`"rider`"[^\]]*`"vagrant`""
    }

    It 'fails on an unknown pick' {
        $result = Invoke-InitTemplate -Env @{ DOTFILES_PROFILES = 'apps'; DOTFILES_PICKS_APPS = 'ridr' }

        $result.ExitCode | Should -Not -Be 0
        $result.Error | Should -Match 'ridr'
    }

    It 'writes offered for every pick profile' {
        $result = Invoke-InitTemplate -Env @{ DOTFILES_PROFILES = 'shell' }

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match '(?s)\[data\.offered\].*apps = \[[^\]]*"rider"'
        $result.Output | Should -Match '(?s)\[data\.offered\].*apps = \[[^\]]*"googlechrome"'
        $result.Output | Should -Match '(?s)\[data\.offered\].*apps = \[[^\]]*"postman"'
        $result.Output | Should -Match '(?s)\[data\.offered\].*apps = \[[^\]]*"vagrant"'
        $result.Output | Should -Match "(?s)\[data\.offered\].*ai = \[$([regex]::Escape($aiList))\]"
    }

    It 'keeps stored picks and preselects new items with --promptDefaults' {
        $existing = @'
        [data]
        profiles = ["apps"]
        [data.picks]
        apps = ["rider"]
        [data.offered]
        apps = ["rider", "googlechrome", "vscode"]
'@
        $result = Invoke-InitTemplate -Existing $existing -Flags '--prompt', '--promptDefaults'

        $result.ExitCode | Should -Be 0
        # stored (rider) + not offered before (postman, vagrant); googlechrome was offered and left off
        $result.Output | Should -Match '(?s)\[data\.picks\]\s+apps = \["rider", ?"postman", ?"vagrant"\]'
    }

    It 'keeps an empty stored selection with --promptDefaults' {
        $result = Invoke-InitTemplate -Existing "[data]`nprofiles = []" -Flags '--prompt', '--promptDefaults'

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'profiles = \[\]'
    }

    It 'drops a stored profile that no longer exists, under --prompt' {
        $result = Invoke-InitTemplate -Existing "[data]`nprofiles = [`"shell`", `"gone`"]" -Flags '--prompt', '--promptDefaults'

        $result.ExitCode | Should -Be 0 -Because $result.Error
        $result.Output | Should -Match 'profiles = \["shell"\]'
    }

    It 'drops a stored profile that no longer exists, on a plain init' {
        $result = Invoke-InitTemplate -Existing "[data]`nprofiles = [`"shell`", `"gone`"]"

        $result.ExitCode | Should -Be 0 -Because $result.Error
        $result.Output | Should -Match 'profiles = \["shell"\]'
    }

    It 'drops a stored pick that no longer exists, under --prompt' {
        $existing = @"
        [data]
        profiles = ["apps"]
        [data.picks]
        apps = ["rider", "removed"]
        [data.offered]
        apps = [$(ConvertTo-TomlList ($appsLabels + 'removed'))]
"@
        $result = Invoke-InitTemplate -Existing $existing -Flags '--prompt', '--promptDefaults'

        $result.ExitCode | Should -Be 0 -Because $result.Error
        $result.Output | Should -Match '(?s)\[data\.picks\]\s+apps = \["rider"\]'
        $result.Output | Should -Not -Match 'removed'
    }

    It 'drops a stored pick that no longer exists, on a plain init' {
        $existing = "[data]`nprofiles = [`"apps`"]`n[data.picks]`napps = [`"rider`", `"removed`"]"
        $result = Invoke-InitTemplate -Existing $existing

        $result.ExitCode | Should -Be 0 -Because $result.Error
        $result.Output | Should -Match '(?s)\[data\.picks\]\s+apps = \["rider"\]'
    }

    It 'keeps offered and the pending items on an init without --prompt' -ForEach @(
        @{ Flags = @() }
        @{ Flags = @('--promptDefaults') }
    ) {
        $result = Invoke-InitTemplate -Existing $narrowOffer -Flags $Flags

        $result.ExitCode | Should -Be 0 -Because $result.Error
        $result.Output | Should -Match '(?s)\[data\.picks\]\s+apps = \["rider"\]'
        $result.Output | Should -Match '(?s)\[data\.offered\].*apps = \["rider"\]'
        $pending = Get-Pending $result.Config
        $pending.apps | Should -Be @($appsLabels | Where-Object { $_ -ne 'rider' })
    }

    It 'refreshes offered to every item under --prompt' {
        $result = Invoke-InitTemplate -Existing $narrowOffer -Flags '--prompt', '--promptDefaults'

        $result.ExitCode | Should -Be 0 -Because $result.Error
        $result.Output | Should -Match "(?s)\[data\.offered\].*apps = \[$([regex]::Escape((ConvertTo-TomlList $appsLabels)))\]"
        (Get-Pending $result.Config).PSObject.Properties | Should -BeNullOrEmpty
    }

    It 'refreshes offered to every item in environment mode' {
        $result = Invoke-InitTemplate -Existing $narrowOffer -Env @{ DOTFILES_PROFILES = 'apps' }

        $result.ExitCode | Should -Be 0 -Because $result.Error
        $result.Output | Should -Match "(?s)\[data\.offered\].*apps = \[$([regex]::Escape((ConvertTo-TomlList $appsLabels)))\]"
    }

    It 'keeps the stored answer without --prompt' {
        $result = Invoke-InitTemplate -Existing "[data]`nprofiles = [`"shell`"]"

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'profiles = \["shell"\]'
    }
}
