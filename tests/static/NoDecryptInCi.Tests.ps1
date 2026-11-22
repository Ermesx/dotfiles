#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    Import-Module "$PSScriptRoot/StaticChecks.psm1" -Force
    $root = Resolve-Path "$PSScriptRoot/../.."

    # A minimal chezmoi source: <dir>/.chezmoiroot = home, then each relative path under home/
    function New-Fixture([hashtable]$files) {
        $dir = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path (Join-Path $dir 'home') -Force | Out-Null
        Set-Content -Path (Join-Path $dir '.chezmoiroot') -Value 'home' -NoNewline
        foreach ($relative in $files.Keys) {
            $path = Join-Path $dir 'home' $relative
            New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
            Set-Content -Path $path -Value $files[$relative] -NoNewline
        }
        $dir
    }
}

Describe 'no decryption when CI is set' {

    It 'finds no decryption in the repo with CI set' {
        Get-CiDecryptionViolation -Source $root | Should -BeNullOrEmpty
    }

    It 'ignores exactly the agreed targets in CI' {
        Get-CiIgnoredTarget -Source $root | Should -Be @(
            '.chezmoiscripts/windows/add-ssh-key.ps1'
            '.chezmoiscripts/windows/decrypt-private-key.ps1'
            '.chezmoiscripts/windows/install-wsl.ps1'
            '.config/git/user.gitconfig'
            '.ssh/id_ed25519'
            '.ssh/id_ed25519.pub'
        )
    }

    It 'keeps the identity managed when CI is <_>, not true' -ForEach '1', 'false' {
        # A toolchain may leave CI set on a real machine; only GitHub's CI=true may drop the identity
        $config = Join-Path $TestDrive 'empty.toml'
        Set-Content -Path $config -Value ''
        $previous = $env:CI
        try {
            $env:CI = $_
            $ignore = Get-Content -Raw (Join-Path $root 'home/.chezmoiignore') |
                chezmoi --config $config --source $root execute-template
            $exitCode = $LASTEXITCODE
        } finally {
            $env:CI = $previous
        }

        # A failed or empty render would pass the last assertion on its own
        $exitCode | Should -Be 0
        $ignore | Should -Contain '.claude/*'
        $ignore | Should -Not -Contain '.config/git/user.gitconfig'
    }

    It 'reports an unguarded decrypt template' {
        $source = New-Fixture @{ 'dot_leak.tmpl' = '{{ "x" | decrypt }}' }

        Get-CiDecryptionViolation -Source $source | Should -Be 'dot_leak.tmpl'
    }

    It 'reports decrypt in a shared template' {
        $source = New-Fixture @{ '.chezmoitemplates/t.tmpl' = '{{ "x" | decrypt }}' }

        Get-CiDecryptionViolation -Source $source | Should -Contain '.chezmoitemplates/t.tmpl'
    }

    It 'reports a plain script that decrypts' {
        $source = New-Fixture @{ '.chezmoiscripts/run_once_x.ps1' = 'chezmoi age decrypt --passphrase k.age' }

        Get-CiDecryptionViolation -Source $source | Should -Contain '.chezmoiscripts/run_once_x.ps1'
    }

    It 'reports decrypt in the config template' {
        $source = New-Fixture @{ '.chezmoi.toml.tmpl' = '[data]{{ "x" | decrypt }}' }

        Get-CiDecryptionViolation -Source $source | Should -Contain '.chezmoi.toml.tmpl'
    }

    It 'reports decrypt in an external definition' {
        $source = New-Fixture @{ '.chezmoiexternal.toml.tmpl' = '{{ decrypt "x" }}' }

        Get-CiDecryptionViolation -Source $source | Should -Contain '.chezmoiexternal.toml.tmpl'
    }

    It 'does not report a file that only names decrypt in text' {
        $source = New-Fixture @{ 'dot_notes.md' = 'see decrypt-private-key.ps1 for how keys are decrypted' }

        Get-CiDecryptionViolation -Source $source | Should -BeNullOrEmpty
    }

    It 'reports an encrypted file that CI does not ignore' {
        $source = New-Fixture @{ 'encrypted_secret.age' = 'not-really-age' }

        Get-CiDecryptionViolation -Source $source | Should -Contain 'encrypted_secret.age'
    }
}
