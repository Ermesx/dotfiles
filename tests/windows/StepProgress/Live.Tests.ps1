#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    Import-Module StepProgress -Force

    function Invoke-Captured([scriptblock]$Script) {
        $all = & $Script 6>&1
        @{
            Lines  = @($all | Where-Object { $_ -is [System.Management.Automation.InformationRecord] } | ForEach-Object { "$($_.MessageData)" })
            Result = @($all | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] })
        }
    }

    $script:clear = "`r`e[2K"
}

Describe 'Resolve-ProgressMode' {

    BeforeEach { $script:savedCi = $env:CI }
    AfterEach { $env:CI = $script:savedCi }

    It 'passes an explicit mode through' {
        InModuleScope StepProgress {
            Resolve-ProgressMode -Mode Plain | Should -BeExactly 'Plain'
            Resolve-ProgressMode -Mode Live | Should -BeExactly 'Live'
        }
    }

    It 'resolves Auto to Plain in CI' {
        $env:CI = 'true'
        InModuleScope StepProgress { Resolve-ProgressMode -Mode Auto | Should -BeExactly 'Plain' }
    }
}

Describe 'Format-LiveLine' {

    It 'fills the bar by completed items' {
        InModuleScope StepProgress {
            $line = Format-LiveLine -Index 3 -Total 4 -Text x -Width 80
            $line.StartsWith(('█' * 12) + ('░' * 12)) | Should -BeTrue
            $line | Should -Match ' 3/4  x'

            (Format-LiveLine -Index 1 -Total 4 -Text x -Width 80).StartsWith('░' * 24) | Should -BeTrue
        }
    }

    It 'uses ASCII characters with -Ascii' {
        InModuleScope StepProgress {
            (Format-LiveLine -Index 3 -Total 4 -Text x -Width 80 -Ascii).StartsWith(('#' * 12) + ('-' * 12)) | Should -BeTrue
        }
    }

    It 'cuts the line to one column short of the width' {
        InModuleScope StepProgress {
            $line = Format-LiveLine -Index 3 -Total 4 -Text 'a long name' -Width 20
            $line.Length | Should -BeLessOrEqual 19
            $line | Should -Match '…$'
        }
    }
}

Describe 'Get-ProgressWidth' {

    It 'returns a usable width and never throws' {
        InModuleScope StepProgress {
            { Get-ProgressWidth } | Should -Not -Throw
            Get-ProgressWidth | Should -BeOfType [int]
            Get-ProgressWidth | Should -BeGreaterOrEqual 20
        }
    }
}

Describe 'Invoke-ProgressSteps (live mode)' {

    It 'draws a live line before each item and replaces it with the finished line' {
        $r = Invoke-Captured { Invoke-ProgressSteps -Title 'T' -Items 'a', 'b', 'c' -Action { param($i) } -Mode Live }

        $lines = $r.Lines
        $liveIndex = 0..($lines.Count - 1) | Where-Object { $lines[$_].StartsWith($script:clear) -and $lines[$_] -match '1/3' -and $lines[$_] -match 'a$' } | Select-Object -First 1
        $finishedIndex = 0..($lines.Count - 1) | Where-Object { $lines[$_] -match '✓ a ' } | Select-Object -First 1

        $liveIndex | Should -Not -BeNullOrEmpty
        $finishedIndex | Should -BeGreaterThan $liveIndex
        $lines[$finishedIndex].StartsWith($script:clear) | Should -BeTrue
        $lines[$finishedIndex + 2].StartsWith($script:clear) | Should -BeTrue
    }

    It 'leaves the summary as the last line, not a live line' {
        $r = Invoke-Captured { Invoke-ProgressSteps -Title 'T' -Items 'a', 'b', 'c' -Action { param($i) } -Mode Live }

        $r.Lines[-1] | Should -Match '^✓ 3 installed in'
    }

    It 'clears the live line when something unexpected throws' {
        $r = Invoke-Captured {
            $caught = $null
            try {
                Invoke-ProgressSteps -Title 'T' -Items 'a', 'b' -Mode Live -Action { param($i) } `
                    -Detail { param($i) if ($i -eq 'b') { throw 'detail broke' } }
            }
            catch { $caught = $_ }
            $caught
        }

        $r.Result | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | Should -Not -BeNullOrEmpty
        $r.Lines[-1] | Should -BeExactly $script:clear
    }

    It 'colours the header cyan and failures red, but not successes' {
        Mock Write-Host {} -ModuleName StepProgress

        Invoke-ProgressSteps -Title 'T' -Items 'a', 'b' -Mode Live -Action { param($i) if ($i -eq 'b') { throw 'boom' } } | Out-Null

        Should -Invoke Write-Host -ModuleName StepProgress -ParameterFilter { $Object -like '► *' -and $ForegroundColor -eq 'Cyan' }
        Should -Invoke Write-Host -ModuleName StepProgress -ParameterFilter { $Object -like '*✗ b' -and $ForegroundColor -eq 'Red' }
        Should -Invoke Write-Host -ModuleName StepProgress -ParameterFilter { $Object -like '*✓ a *' -and -not $ForegroundColor }
    }

    It 'prints no escape characters in plain mode' {
        $r = Invoke-Captured { Invoke-ProgressSteps -Title 'T' -Items 'a', 'b' -Action { param($i) } -Mode Plain }

        $r.Lines | Where-Object { $_ -match "`e" } | Should -BeNullOrEmpty
    }
}
