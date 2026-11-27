#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Post-apply (CI and the VM): the git identity the applied dotfiles produce (docs/specs/git-identity.md).
# What init stored is read from chezmoi's data. CI stores the test email of the apply step; the VM stores
# -WorkEmail, or nothing (a private machine).
BeforeDiscovery {
    $configured = [bool]((chezmoi data --format json | ConvertFrom-Json).git.work_email)
    # CI never decrypts, so the personal identity file exists only on the VM
    $hasPersonalFile = Test-Path (Join-Path $HOME '.config/git/user.gitconfig')
}

BeforeAll {
    $workEmail = [string](chezmoi data --format json | ConvertFrom-Json).git.work_email

    # The identity a github.com repo must get back: the one in the decrypted personal file (the VM only)
    $personalFile = Join-Path $HOME '.config/git/user.gitconfig'
    $personalEmail = if (Test-Path $personalFile) { [string](git config --file $personalFile user.email) } else { '' }

    # user.email git reports in a new repo with these remotes (the first is origin), under the real global config
    function Get-RepoEmail([string[]]$Remotes) {
        $repo = Join-Path $TestDrive "repo-$([guid]::NewGuid())"
        git init -q $repo
        for ($i = 0; $i -lt $Remotes.Count; $i++) {
            git -C $repo remote add $(if ($i -eq 0) { 'origin' } else { "remote$i" }) $Remotes[$i]
        }
        (git -C $repo config user.email) -join ''
    }
}

AfterAll {
    # `git config` exits 1 for a key that is not set; a leftover non-zero code would fail the CI step after a green run
    $global:LASTEXITCODE = 0
}

Describe 'git identity after apply' {

    Context 'a private machine' -Skip:$configured {

        It 'sets no email and no includeIf in ~/.gitconfig' {
            # No --includes: on the VM the decrypted personal file exists and is included, which is not what this checks
            git config --global --get user.email | Should -BeNullOrEmpty
            @(git config --global --get-regexp '^includeif\.') | Should -BeNullOrEmpty
        }
    }

    Context 'a work machine' -Skip:(-not $configured) {

        It 'adds the three github.com includeIf entries' {
            @(git config --global --get-regexp '^includeif\..*github\.com.*\.path$') | Should -HaveCount 3
        }

        It 'gives the work email to a repo without a remote' {
            Get-RepoEmail @() | Should -BeExactly $workEmail
        }

        It 'gives the work email to a repo on another host' {
            Get-RepoEmail @('https://ghes.corp.example/o/r') | Should -BeExactly $workEmail
        }

        It 'gives the personal email to a github.com repo as <Remote>' -Skip:(-not $hasPersonalFile) -ForEach @(
            @{ Remote = 'https://github.com/o/r.git' }
            @{ Remote = 'git@github.com:o/r.git' }
            @{ Remote = 'ssh://git@github.com/o/r.git' }
        ) {
            $personalEmail | Should -Not -BeNullOrEmpty -Because 'the personal file must define an email, or this check proves nothing'
            $personalEmail | Should -Not -BeExactly $workEmail
            Get-RepoEmail @($Remote) | Should -BeExactly $personalEmail
        }
    }
}
