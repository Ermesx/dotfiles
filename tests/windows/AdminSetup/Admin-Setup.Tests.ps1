#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

Describe 'admin-setup.ps1' {

    BeforeAll {
        . "$PSScriptRoot/AdminSetup.Helpers.ps1"
        $relative = 'dot_config/dotfiles/admin/admin-setup.ps1.tmpl'

        # Copies the aggregate next to stub item scripts and runs it in a child pwsh from another directory.
        # Each stub logs its name; the one named $Failing then writes a non-terminating error.
        function Invoke-Aggregate([string]$Failing, [hashtable]$Data) {
            $dir = Join-Path $TestDrive ([guid]::NewGuid()) 'admin'
            New-Item -ItemType Directory -Path $dir | Out-Null
            Copy-Item (Get-RenderedScript $relative $Data) $dir
            foreach ($name in 'enable-developer-mode', 'enable-ssh-agent', 'enable-wsl') {
                $body = "Add-Content (Join-Path `$PSScriptRoot 'log.txt') '$name'"
                if ($name -eq $Failing) { $body += "`nWrite-Error 'denied'" }
                Set-Content (Join-Path $dir "$name.ps1") $body
            }

            Push-Location $TestDrive
            try {
                $output = pwsh -NoProfile -File (Join-Path $dir 'admin-setup.ps1') *>&1 | Out-String
                $exitCode = $LASTEXITCODE
            }
            finally {
                Pop-Location
            }

            [pscustomobject]@{
                Output   = $output
                ExitCode = $exitCode
                Log      = @(Get-Content (Join-Path $dir 'log.txt') -ErrorAction SilentlyContinue)
            }
        }
    }

    It 'runs the three items in order' {
        $run = Invoke-Aggregate

        $run.Log | Should -Be @('enable-developer-mode', 'enable-ssh-agent', 'enable-wsl')
        $run.ExitCode | Should -Be 0
    }

    It 'skips enable-wsl without a need' {
        $run = Invoke-Aggregate -Data @{ profiles = @('shell') }

        $run.Log | Should -Be @('enable-developer-mode', 'enable-ssh-agent')
        $run.ExitCode | Should -Be 0
    }

    It 'ends with the per-user recap' {
        $run = Invoke-Aggregate

        $run.Output | Should -Match 'Next steps'
        $run.Output | Should -BeLike '*Restart the computer*'
        $run.Output | Should -BeLike '*Complete-UserSetup*'
    }

    It 'stops at the first failing item and prints no recap' {
        $run = Invoke-Aggregate -Failing 'enable-ssh-agent'

        $run.Log | Should -Be @('enable-developer-mode', 'enable-ssh-agent')
        $run.ExitCode | Should -Not -Be 0
        $run.Output | Should -Not -Match 'Next steps'
    }
}
