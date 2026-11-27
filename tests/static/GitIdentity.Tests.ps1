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

    # The personal identity file a work machine re-includes for github.com. Absolute and in C:/ form: git on Windows
    # ignores an MSYS /c/... path in `path =` without an error
    $stub = (Join-Path $TestDrive 'user.gitconfig') -replace '\\', '/'
    Set-Content -Path $stub -Value "[user]`n  email = personal@example.com"

    # dot_gitconfig.tmpl as a machine with this work email renders it ($null: no [data.git] at all, a config from
    # before #60), with its include of ~/.config/git/user.gitconfig pointed at the stub
    function Get-RenderedGitConfig([AllowNull()][string]$WorkEmail) {
        $config = Join-Path $TestDrive "$([guid]::NewGuid()).toml"
        Set-Content -Path $config -Value $(if ($null -eq $WorkEmail) { '' } else { "[data.git]`nwork_email = `"$WorkEmail`"" })
        $text = (Get-Content -Raw (Join-Path $root 'home/dot_gitconfig.tmpl') |
            & chezmoi --source $root --config $config execute-template) -join "`n"
        $text.Replace('~/.config/git/user.gitconfig', $stub)
    }

    # user.email git reports in a new repo with these remotes (the first is origin), reading only $GlobalConfig
    function Get-RepoEmail([string]$GlobalConfig, [string[]]$Remotes) {
        $repo = Join-Path $TestDrive "repo-$([guid]::NewGuid())"
        & git init -q $repo
        for ($i = 0; $i -lt $Remotes.Count; $i++) {
            & git -C $repo remote add $(if ($i -eq 0) { 'origin' } else { "remote$i" }) $Remotes[$i]
        }
        $saved = @{}
        foreach ($name in 'GIT_CONFIG_GLOBAL', 'GIT_CONFIG_NOSYSTEM') { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
        try {
            $env:GIT_CONFIG_GLOBAL = $GlobalConfig
            $env:GIT_CONFIG_NOSYSTEM = '1'
            (& git -C $repo config user.email) -join ''
        } finally {
            foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
        }
    }

    # A global git config rendered for $WorkEmail, written to a file git can read
    function New-GlobalConfig([AllowNull()][string]$WorkEmail) {
        $path = (Join-Path $TestDrive "$([guid]::NewGuid()).gitconfig") -replace '\\', '/'
        Set-Content -Path $path -Value (Get-RenderedGitConfig $WorkEmail)
        $path
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

Describe 'dot_gitconfig.tmpl' {

    It 'renders identically with no data and with an empty email' {
        Get-RenderedGitConfig $null | Should -BeExactly (Get-RenderedGitConfig '')
    }

    It 'has no [user] and no includeIf without a work email' {
        $text = Get-RenderedGitConfig ''

        $text | Should -Not -Match '\[user\]'
        $text | Should -Not -Match 'includeIf'
    }

    It 'adds the work block after the include' {
        $text = Get-RenderedGitConfig 'w@x'

        $patterns = 'https://github.com/**', 'git@github.com:*/**', 'ssh://git@github.com/**'
        $expected = @("[include]`npath = $stub", "[user]`nemail = w@x") +
            @($patterns | ForEach-Object { "[includeIf `"hasconfig:remote.*.url:$_`"]`npath = $stub" })
        $positions = $expected | ForEach-Object { $text.IndexOf($_) }

        $positions | Should -Not -Contain -1
        ($positions | Sort-Object) | Should -Be $positions
    }
}

Describe 'user.email by remote on a work machine' {

    BeforeAll { $work = 'first.last+work@corp.example'; $workConfig = New-GlobalConfig $work }

    It 'gives the personal email to github.com as <Remote>' -ForEach @(
        @{ Remote = 'https://github.com/Ermesx/dotfiles.git' }
        @{ Remote = 'git@github.com:Ermesx/dotfiles.git' }
        @{ Remote = 'ssh://git@github.com/Ermesx/dotfiles.git' }
    ) {
        Get-RepoEmail $workConfig @($Remote) | Should -BeExactly 'personal@example.com'
    }

    It 'gives the work email to <Remote>' -ForEach @(
        @{ Remote = 'https://ghes.corp.example/o/r.git' }
        @{ Remote = 'git@ghes.corp.example:o/r.git' }
        @{ Remote = 'https://dev.azure.com/o/p/_git/r' }
    ) {
        Get-RepoEmail $workConfig @($Remote) | Should -BeExactly $work
    }

    It 'gives the work email to a repo without a remote' {
        Get-RepoEmail $workConfig @() | Should -BeExactly $work
    }

    It 'falls back to the work email for the unmatched form <Remote>' -ForEach @(
        @{ Remote = 'https://github.com.evil/o/r' }
        @{ Remote = 'https://user@github.com/o/r.git' }
    ) {
        Get-RepoEmail $workConfig @($Remote) | Should -BeExactly $work
    }

    It 'counts any remote, not only origin' {
        Get-RepoEmail $workConfig @('https://ghes.corp.example/o/r', 'https://github.com/o/r') | Should -BeExactly 'personal@example.com'
    }
}

Describe 'user.email on a private machine' {

    It 'stays personal for <Case>' -ForEach @(
        @{ Case = 'github.com'; Remotes = @('https://github.com/o/r') }
        @{ Case = 'a repo without a remote'; Remotes = @() }
        @{ Case = 'another host'; Remotes = @('https://ghes.corp.example/o/r') }
    ) {
        Get-RepoEmail (New-GlobalConfig '') $Remotes | Should -BeExactly 'personal@example.com'
    }
}
