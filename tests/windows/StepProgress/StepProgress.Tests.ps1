#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

Describe 'Invoke-ProgressSteps (plain mode)' {

    BeforeAll {
        Import-Module StepProgress -Force

        function Invoke-Captured([scriptblock]$Script) {
            $all = & $Script 6>&1
            @{
                Lines  = @($all | Where-Object { $_ -is [System.Management.Automation.InformationRecord] } | ForEach-Object { "$($_.MessageData)" })
                Result = @($all | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] })
            }
        }
    }

    It 'prints the title, then one check line per item' {
        $r = Invoke-Captured { Invoke-ProgressSteps -Title 'Installing things' -Items 'a', 'b' -Action { param($i) } -Mode Plain }

        $r.Lines[0] | Should -BeExactly '► Installing things'
        $r.Lines[1] | Should -Match '^✓ a +\d+\.\ds$'
        $r.Lines[2] | Should -Match '^✓ b +\d+\.\ds$'
    }

    It 'counts the items it ran' {
        $r = Invoke-Captured { Invoke-ProgressSteps -Title 'T' -Items 'a', 'b' -Action { param($i) } -Mode Plain }

        $r.Result.Done | Should -Be 2
        $r.Result.Present | Should -Be 0
        $r.Lines[-1] | Should -Match '^✓ 2 installed in \d'
    }

    It 'does not run or list present items' {
        $script:called = @()
        $r = Invoke-Captured {
            Invoke-ProgressSteps -Title 'T' -Items 'a', 'b', 'c' -IsPresent { param($i) $i -ne 'b' } -Action { param($i) $script:called += $i } -Mode Plain
        }

        $script:called | Should -Be @('b')
        $r.Lines | Where-Object { $_ -like '✓ a*' -or $_ -like '✓ c*' } | Should -BeNullOrEmpty
        $r.Result.Done | Should -Be 1
        $r.Result.Present | Should -Be 2
        $r.Lines[-1] | Should -BeExactly '✓ 1 installed, 2 already present'
    }

    It 'prints nothing when the module is imported' {
        Import-Module StepProgress -Force 6>&1 4>&1 3>&1 | Should -BeNullOrEmpty
    }

    It 'reports all present items without running the action' {
        $script:called = 0
        $r = Invoke-Captured {
            Invoke-ProgressSteps -Title 'T' -Items 'a', 'b', 'c' -IsPresent { param($i) $true } -Action { param($i) $script:called++ } -Mode Plain
        }

        $r.Result.Done | Should -Be 0
        $r.Result.Present | Should -Be 3
        $script:called | Should -Be 0
        $r.Lines[-1] | Should -BeExactly '✓ 3 already present'
    }

    It 'prints no summary for a single item that succeeded with nothing present' {
        $r = Invoke-Captured { Invoke-ProgressSteps -Title 'T' -Items 'a' -Action { param($i) } -Mode Plain }

        $r.Lines | Where-Object { $_ -like '✓ 1 installed*' } | Should -BeNullOrEmpty
    }

    It 'words the summary and shows the detail with -Verb Updated' {
        $r = Invoke-Captured {
            Invoke-ProgressSteps -Title 'T' -Items 'a', 'b' -Verb Updated -Detail { '1.0 → 2.0' } -Action { param($i) } -Mode Plain
        }

        $r.Lines[-1] | Should -Match '^✓ 2 updated in '
        $r.Lines[1] | Should -Match '1\.0 → 2\.0'
    }

    It 'fails an item whose action throws and goes on' {
        $r = Invoke-Captured {
            Invoke-ProgressSteps -Title 'T' -Items 'a', 'b', 'c' -Action { param($i) if ($i -eq 'b') { throw 'boom' } } -Mode Plain
        }

        $r.Lines | Should -Contain '✗ b'
        $r.Lines | Should -Contain '    boom'
        ($r.Lines | Where-Object { $_ -match '^✓ c ' }) | Should -Not -BeNullOrEmpty
        $r.Result.Failed.Name | Should -Be 'b'
        $r.Lines[-1] | Should -BeExactly '✗ 1 failed: b'
    }

    It 'fails an item on a non-zero exit code and shows its output' {
        $r = Invoke-Captured {
            Invoke-ProgressSteps -Title 'T' -Items 'a' -Action { param($i) Write-Host 'tool said no'; $global:LASTEXITCODE = 1 } -Mode Plain
        }

        $r.Result.Failed[0].Output | Should -Match 'tool said no'
        $idx = [array]::IndexOf($r.Lines, '✗ a')
        $idx | Should -BeGreaterOrEqual 0
        $r.Lines[$idx + 1] | Should -Match '^    tool said no'
    }

    It 'keeps the output an item printed before it threw' {
        $r = Invoke-Captured {
            Invoke-ProgressSteps -Title 'T' -Items 'a' -Action { param($i) Write-Host 'x'; throw 'y' } -Mode Plain
        }

        $idx = [array]::IndexOf($r.Lines, '✗ a')
        $idx | Should -BeGreaterOrEqual 0
        $r.Lines[$idx + 1] | Should -BeExactly '    x'
        $r.Lines[$idx + 2] | Should -BeExactly '    y'
        $r.Result.Failed[0].Output | Should -Match 'x\s+y'
    }

    It 'does not carry a stale exit code over to the next item' {
        $r = Invoke-Captured {
            Invoke-ProgressSteps -Title 'T' -Items 'a', 'b' -Action { param($i) if ($i -eq 'a') { $global:LASTEXITCODE = 1 } } -Mode Plain
        }

        @($r.Result.Failed).Count | Should -Be 1
        $r.Result.Failed.Name | Should -Be 'a'
    }

    It 'discards the output of a successful item' {
        $r = Invoke-Captured { Invoke-ProgressSteps -Title 'T' -Items 'a' -Action { param($i) Write-Host 'chatter' } -Mode Plain }

        $r.Lines | Where-Object { $_ -match 'chatter' } | Should -BeNullOrEmpty
    }

    It 'does not treat success pipeline values of the action as results' {
        $r = Invoke-Captured { Invoke-ProgressSteps -Title 'T' -Items 'a' -Action { param($i) 'x'; 42 } -Mode Plain }

        @($r.Result).Count | Should -Be 1
        $r.Lines | Where-Object { $_ -match '^(x|42)$' } | Should -BeNullOrEmpty
    }

    It 'prints only the header for empty items' {
        $r = Invoke-Captured { Invoke-ProgressSteps -Title 'T' -Items @() -Action { param($i) } -Mode Plain }

        $r.Lines.Count | Should -Be 1
        $r.Lines[0] | Should -BeExactly '► T'
        $r.Result.Done | Should -Be 0
    }

    It 'always returns Failed as an array' {
        $r = Invoke-Captured { Invoke-ProgressSteps -Title 'T' -Items 'a' -Action { param($i) } -Mode Plain }

        # Index first: member enumeration over the result array would flatten an empty Failed to $null
        $failed = $r.Result[0].Failed
        ($failed -is [array]) | Should -BeTrue
        $failed.Count | Should -Be 0
    }

    It 'pads names to the longest one that runs' {
        $r = Invoke-Captured {
            Invoke-ProgressSteps -Title 'T' -Items 'a', 'long-name' -Action { param($i) } -Mode Plain
        }

        $r.Lines[1] | Should -Match '^✓ a {9}  ?\d'
    }

    It 'writes no control characters in plain mode' {
        $r = Invoke-Captured { Invoke-ProgressSteps -Title 'T' -Items 'a', 'b' -Action { param($i) if ($i -eq 'b') { throw 'x' } } -Mode Plain }

        $r.Lines | Where-Object { $_ -match '\x1b' } | Should -BeNullOrEmpty
    }
}

Describe 'Format helpers' {

    BeforeAll { Import-Module StepProgress -Force }

    It 'Format-Elapsed formats <Seconds> seconds as <Expected>' -ForEach @(
        @{ Seconds = 6.14; Expected = '6.1s' }
        @{ Seconds = 0; Expected = '0.0s' }
        @{ Seconds = 72.4; Expected = '1m 12s' }
    ) {
        InModuleScope StepProgress -Parameters @{ Seconds = $Seconds; Expected = $Expected } {
            Format-Elapsed ([timespan]::FromSeconds($Seconds)) | Should -BeExactly $Expected
        }
    }

    It 'Format-Summary returns an empty string when nothing was done or present' {
        InModuleScope StepProgress {
            Format-Summary -Done 0 -Present 0 -Verb Installed -Elapsed ([timespan]::Zero) | Should -BeExactly ''
        }
    }
}
