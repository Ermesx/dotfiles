#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# tests/run-tests.ps1 is read, never run: its -Picks parsing function is taken out of the syntax tree
BeforeAll {
    $path = Resolve-Path "$PSScriptRoot/../run-tests.ps1"
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)
    $function = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'ConvertTo-PickEnvironment' }, $true)
    . ([scriptblock]::Create($function.Extent.Text))
}

Describe 'run-tests.ps1 parameters' {

    It 'takes -Profiles and -Picks as strings, the only type -File passes' {
        $types = $ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -in 'Profiles', 'Picks' } |
            ForEach-Object { $_.StaticType.Name }

        $types | Should -HaveCount 2
        $types | Should -Not -Contain 'Hashtable'
        $types | Should -Not -Contain 'String[]'
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