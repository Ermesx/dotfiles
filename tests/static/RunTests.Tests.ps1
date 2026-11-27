#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# tests/run-tests.ps1 is read, never run: its -Picks parsing function is taken out of the syntax tree
BeforeAll {
    $path = Resolve-Path "$PSScriptRoot/../run-tests.ps1"
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)
    $function = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'ConvertTo-PickEnvironment' }, $true)
    . ([scriptblock]::Create($function.Extent.Text))
    $function = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'ConvertTo-ProfileList' }, $true)
    . ([scriptblock]::Create($function.Extent.Text))
}

Describe 'run-tests.ps1 parameters' {

    It 'types -Profiles as String[] (console) and -Picks as String (-File passes strings)' {
        $types = @{}
        $ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -in 'Profiles', 'Picks' } |
            ForEach-Object { $types[$_.Name.VariablePath.UserPath] = $_.StaticType.Name }

        $types['Profiles'] | Should -Be 'String[]'
        $types['Picks'] | Should -Be 'String'
    }

    It 'types -WorkEmail as String' {
        $parameter = $ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'WorkEmail' }

        $parameter.StaticType.Name | Should -Be 'String'
    }

    It 'removes a leaked DOTFILES_GIT_WORK_EMAIL before it sets its own' {
        $text = Get-Content -Raw $path

        $text | Should -Match 'Remove-Item env:DOTFILES_GIT_WORK_EMAIL'
        $text | Should -Match '\$env:DOTFILES_GIT_WORK_EMAIL = \$WorkEmail'
    }

    It 'gives the same profile list for -File (one element) and the console (an array)' {
        ConvertTo-ProfileList @('shell,sdk,ai') | Should -BeExactly 'shell,sdk,ai'
        ConvertTo-ProfileList @('shell', 'sdk', 'ai') | Should -BeExactly 'shell,sdk,ai'
        ConvertTo-ProfileList @('shell, sdk', 'ai') | Should -BeExactly 'shell,sdk,ai'
    }

    It 'turns profile=labels parts into one picks variable per profile' {
        $result = ConvertTo-PickEnvironment 'ai=claude-code;apps=rider, postman'

        $result.Keys | Should -HaveCount 2
        $result['DOTFILES_PICKS_AI'] | Should -BeExactly 'claude-code'
        $result['DOTFILES_PICKS_APPS'] | Should -BeExactly 'rider,postman'
    }

    It 'returns nothing for no picks' {
        (ConvertTo-PickEnvironment '').Count | Should -Be 0
        (ConvertTo-PickEnvironment $null).Count | Should -Be 0
    }

    It 'rejects <Text>' -ForEach @(
        @{ Text = 'a part without =';  Picks = 'ai' }
        @{ Text = 'an empty label list'; Picks = 'ai=' }
        @{ Text = 'an empty profile';    Picks = '=claude-code' }
        @{ Text = 'one bad part among good ones'; Picks = 'ai=claude-code;apps' }
    ) {
        { ConvertTo-PickEnvironment $Picks } | Should -Throw '*expected profile=label*'
    }
}