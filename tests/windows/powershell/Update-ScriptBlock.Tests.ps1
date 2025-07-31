#Requires -Modules Pester, Dotfiles-Toolkit

Describe 'Update-ScriptBlock' {
    It 'should replace placeholders with values and return a valid ScriptBlock' {
        $template = { Write-Host "Hello {{name}}, you are {{age}} years old" }
        $values = @{ name = "John"; age = "25" }
        $result = Update-ScriptBlock -ScriptBlockTemplate $template -Values $values
        $result | Should -BeOfType 'ScriptBlock'
        $result.ToString().Trim() | Should -Be 'Write-Host "Hello John, you are 25 years old"'
    }

    It 'should throw if the resulting script block is invalid' {
        $template = { Write-Host "Hello {{name}} {{" }
        $values = @{ name = "John" }
        { Update-ScriptBlock -ScriptBlockTemplate $template -Values $values } | Should -Throw 
    }

    It 'should work with multiple placeholders' {
        $template = { $a = {{one}}; $b = {{two}}; Write-Host $a $b }
        $values = @{ one = 1; two = 2 }
        $result = Update-ScriptBlock -ScriptBlockTemplate $template -Values $values
        $result.ToString().Trim() | Should -Be '$a = 1; $b = 2; Write-Host $a $b'
    }

    It 'should not replace text outside of placeholders' {
        $template = { Write-Host "{{greeting}}, world!" }
        $values = @{ greeting = "Hi" }
        $result = Update-ScriptBlock -ScriptBlockTemplate $template -Values $values
        $result.ToString().Trim() | Should -Be 'Write-Host "Hi, world!"'
    }

    It 'returns valid ScriptBlock for code without placeholders' {
        $template = { Get-Date }
        $values = @{}
        $result = Update-ScriptBlock -ScriptBlockTemplate $template -Values $values
        $result | Should -BeOfType 'ScriptBlock'
        $result.ToString().Trim() | Should -Be 'Get-Date'
    }
}
