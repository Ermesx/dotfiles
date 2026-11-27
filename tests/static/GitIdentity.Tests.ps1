#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The git identity of a work machine (docs/specs/git-identity.md): the work email asked at `chezmoi init`, stored under
# [data.git], and the .gitconfig that makes it the default except for github.com.
# Runs a real `chezmoi init --no-tty` with a temp config and destination: no apply, nothing touches the home.
BeforeAll {
    $root = (Resolve-Path "$PSScriptRoot/../..").Path

    # $Existing is the config already on the machine; Output is the config init wrote.
    # The profiles answer is always stored: under --no-tty the profiles prompt (promptMultichoiceOnce) fails with EOF
    # when nothing is stored and DOTFILES_PROFILES is unset, which is not what these tests are about.
    function Invoke-Init([hashtable]$Env = @{}, [string]$Existing = '') {
        $config = Join-Path $TestDrive "$([guid]::NewGuid()).toml"
        Set-Content -Path $config -Value "[data]`nprofiles = [`"shell`"]`n$Existing"
        $names = @('DOTFILES_PROFILES', 'DOTFILES_GIT_WORK_EMAIL') + @($Env.Keys)
        $saved = @{}
        foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
        try {
            foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $null) }
            foreach ($name in $Env.Keys) { [Environment]::SetEnvironmentVariable($name, $Env[$name]) }
            # --no-tty reads the answers from stdin: one Enter accepts a default, a closed stdin is an EOF error
            '' | & chezmoi --source $root --config $config --destination (Join-Path $TestDrive 'home') init --no-tty 2>&1 | Out-Null
            $exitCode = $LASTEXITCODE
        } finally {
            foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
        }
        [pscustomobject]@{ Output = (Get-Content -Raw $config); ExitCode = $exitCode }
    }
}

Describe 'work email at init' {

    It 'takes the email from the variable' {
        $result = Invoke-Init -Env @{ DOTFILES_GIT_WORK_EMAIL = 'first.last+work@corp.example' }

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'work_email = "first\.last\+work@corp\.example"'
    }

    It 'trims the variable' {
        $result = Invoke-Init -Env @{ DOTFILES_GIT_WORK_EMAIL = '  w@x  ' }

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'work_email = "w@x"'
    }

    It 'treats spaces as a private machine' {
        $result = Invoke-Init -Env @{ DOTFILES_GIT_WORK_EMAIL = '   ' }

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'work_email = ""'
    }

    It 'defaults to empty when the prompt is answered with Enter' {
        $result = Invoke-Init

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'work_email = ""'
    }

    It 'skips the prompt under DOTFILES_PROFILES' {
        $result = Invoke-Init -Env @{ DOTFILES_PROFILES = 'shell' }

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'work_email = ""'
    }

    It 'keeps a stored email under DOTFILES_PROFILES' {
        $result = Invoke-Init -Env @{ DOTFILES_PROFILES = 'shell' } -Existing "[data.git]`nwork_email = `"w@x`""

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'work_email = "w@x"'
    }

    It 'lets the variable override a stored email' {
        $result = Invoke-Init -Env @{ DOTFILES_GIT_WORK_EMAIL = 'v@x' } -Existing "[data.git]`nwork_email = `"w@x`""

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'work_email = "v@x"'
    }

    It 'keeps a stored email on a plain init' {
        $result = Invoke-Init -Existing "[data.git]`nwork_email = `"w@x`""

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'work_email = "w@x"'
    }

    It 'reads the email under the CI conditions' {
        $result = Invoke-Init -Env @{ CI = 'true'; DOTFILES_PROFILES = 'shell'; DOTFILES_GIT_WORK_EMAIL = 'ci-work@example.invalid' }

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'work_email = "ci-work@example\.invalid"'
    }
}
