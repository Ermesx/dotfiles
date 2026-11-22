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

Describe 'template rendering' {

    It 'renders every template in the repo with CI set' {
        Get-TemplateRenderFailure -Source $root | Should -BeNullOrEmpty
    }

    It 'reports a broken template' {
        $source = New-Fixture @{ 'dot_broken.tmpl' = '{{ if }}' }

        $result = @(Get-TemplateRenderFailure -Source $source)

        $result.Count | Should -Be 1
        $result[0].Path | Should -Be 'dot_broken.tmpl'
        $result[0].Error | Should -Not -BeNullOrEmpty
    }

    It 'reports a broken shared template' {
        $source = New-Fixture @{ '.chezmoitemplates/x.tmpl' = '{{ end }}' }

        (Get-TemplateRenderFailure -Source $source).Path | Should -Be '.chezmoitemplates/x.tmpl'
    }

    It 'renders a template that CI ignores' {
        $source = New-Fixture @{
            '.chezmoiignore' = '{{ if env "CI" }}.x{{ end }}'
            'dot_x.tmpl'     = '{{ if }}'
        }

        $result = @(Get-TemplateRenderFailure -Source $source)

        $result.Count | Should -Be 1
        $result[0].Path | Should -Be 'dot_x.tmpl'
    }
}
