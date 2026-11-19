#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

Describe 'After installing dotfiles' {

    BeforeDiscovery {
        $src = Join-Path $PSScriptRoot '../..'
        $sourceArgs = if (Test-Path (Join-Path $src '.chezmoiroot')) { @('--source', (Resolve-Path $src)) } else { @() }
        $view = '{{ includeTemplate "packages.tmpl" . }}' | chezmoi @sourceArgs execute-template | ConvertFrom-Json
        $apps = @($view.scoop | ForEach-Object { ($_ -split '/')[-1] })
        $modules = @($view.modules)
        $tools = @($view.dotnet_tools)
    }

    BeforeAll {
        $installedApps = @(try { scoop list | ForEach-Object Name } catch { })
        $installedModules = @(Get-InstalledModule -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
        $installedTools = @(try { dotnet tool list -g | Select-Object -Skip 2 | ForEach-Object { ($_ -split '\s+')[0] } } catch { })
    }

    Context 'Apps' {
        It 'should have installed <_>' -ForEach $apps {
            $installedApps | Should -Contain $_
        }
    }

    Context 'Modules' {
        It 'should have installed <_>' -ForEach $modules {
            $installedModules | Should -Contain $_
        }
    }

    Context '.NET tools' {
        It 'should have installed <_>' -ForEach $tools {
            $installedTools | Should -Contain $_
        }
    }
}
