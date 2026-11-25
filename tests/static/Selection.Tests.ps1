#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The selection asked at `chezmoi init` (home/.chezmoi.toml.tmpl): profiles, picks and offered items stored under [data].
# Runs a real `chezmoi init` (execute-template has no --prompt) with a temp config and destination: no apply, nothing touches the home.
BeforeAll {
    $root = (Resolve-Path "$PSScriptRoot/../..").Path

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
            Output   = (Get-Content -Raw $config)
            Error    = ($all | Where-Object $isError | ForEach-Object { "$_" }) -join "`n"
            ExitCode = $exitCode
        }
    }
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
        $result.Output | Should -Match '(?s)\[data\.offered\].*ai = \["claude-code"\]'
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

    It 'keeps the stored answer without --prompt' {
        $result = Invoke-InitTemplate -Existing "[data]`nprofiles = [`"shell`"]"

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'profiles = \["shell"\]'
    }
}
