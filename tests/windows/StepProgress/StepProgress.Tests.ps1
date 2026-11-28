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

    It 'joins output written without a newline into one line of a failed item' {
        $r = Invoke-Captured {
            Invoke-ProgressSteps -Title 'T' -Items 'a' -Mode Plain -Action {
                param($i)
                Write-Host 'Checking hash of ' -NoNewline
                Write-Host 'app.zip' -NoNewline
                Write-Host ' ... ' -NoNewline
                Write-Host 'ERROR Hash check failed!'
                throw 'x'
            }
        }

        $idx = [array]::IndexOf($r.Lines, '✗ a')
        $idx | Should -BeGreaterOrEqual 0
        $r.Lines[$idx + 1] | Should -BeExactly '    Checking hash of app.zip ... ERROR Hash check failed!'
        $r.Lines[$idx + 2] | Should -BeExactly '    x'
        $r.Result.Failed[0].Output | Should -Match 'Checking hash of app\.zip \.\.\. ERROR Hash check failed!'
    }

    It 'folds multi-line text that follows a no-newline piece in a failed item' {
        $r = Invoke-Captured {
            Invoke-ProgressSteps -Title 'T' -Items 'a' -Mode Plain -Action {
                param($i)
                Write-Host 'a' -NoNewline
                Write-Host "b`nc" -NoNewline
                Write-Host 'd'
                throw 'x'
            }
        }

        $idx = [array]::IndexOf($r.Lines, '✗ a')
        $idx | Should -BeGreaterOrEqual 0
        $r.Lines[$idx + 1] | Should -BeExactly '    ab'
        $r.Lines[$idx + 2] | Should -BeExactly '    cd'
        $r.Lines[$idx + 3] | Should -BeExactly '    x'
        $r.Result.Failed[0].Output | Should -BeExactly "ab`ncd`nx"
    }

    It 'keeps only the final frame of a progress line redrawn with carriage returns in a failed item' {
        $r = Invoke-Captured {
            Invoke-ProgressSteps -Title 'T' -Items 'a' -Mode Plain -Action {
                param($i)
                Write-Host 'app.zip  10%' -NoNewline
                Write-Host "`rapp.zip  50%" -NoNewline
                Write-Host "`rapp.zip 100%"
                throw 'x'
            }
        }

        $idx = [array]::IndexOf($r.Lines, '✗ a')
        $idx | Should -BeGreaterOrEqual 0
        $r.Lines[$idx + 1] | Should -BeExactly '    app.zip 100%'
        $r.Lines[$idx + 2] | Should -BeExactly '    x'
        $r.Lines.Count | Should -Be ($idx + 3 + 1)
        $r.Lines | Where-Object { $_ -match "`r" } | Should -BeNullOrEmpty
        $r.Result.Failed[0].Output | Should -BeExactly "app.zip 100%`nx"
    }

    It 'keeps the text before a trailing carriage return and empties a line of only carriage returns' {
        $r = Invoke-Captured {
            Invoke-ProgressSteps -Title 'T' -Items 'a' -Mode Plain -Action {
                param($i)
                Write-Host "kept text`r"
                Write-Host "`r`r"
                Write-Host 'last'
                throw 'x'
            }
        }

        $r.Result.Failed[0].Output | Should -BeExactly "kept text`n`nlast`nx"
        $r.Result.Failed[0].Output | Should -Not -Match "`r"
        $r.Lines | Where-Object { $_ -match "`r" } | Should -BeNullOrEmpty
    }

    It 'folds multi-line text that follows a no-newline piece in a successful item' {
        $r = Invoke-Captured {
            Invoke-ProgressSteps -Title 'T' -Items 'a' -Mode Plain -Action {
                param($i)
                Write-Host 'a' -NoNewline
                Write-Host "b`nc" -NoNewline
                Write-Host 'd'
            }
        }

        $r.Result.Done | Should -Be 1
        $r.Result.Failed.Count | Should -Be 0
        $r.Lines | Should -Not -Contain '    ab'
        $r.Lines.Count | Should -Be 2
    }

    It 'fails an item that throws an exception with an empty message' {
        $r = Invoke-Captured {
            Invoke-ProgressSteps -Title 'T' -Items 'a' -Action { param($i) throw [System.Exception]::new('') } -Mode Plain
        }

        $r.Result.Failed.Count | Should -Be 1
        $r.Result.Done | Should -Be 0
        $r.Lines | Should -Contain '✗ a'
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

Describe 'Get-ProgressExitCode' {

    BeforeAll { Import-Module StepProgress -Force }

    It 'returns 1 for a null result' {
        Get-ProgressExitCode $null | Should -Be 1
    }

    It 'returns 0 for the result of a run without failures' {
        $result = Invoke-ProgressSteps -Title 'T' -Items 'a' -Action { param($i) } -Mode Plain 6>$null

        Get-ProgressExitCode $result | Should -Be 0
    }

    It 'returns 1 for the result of a run with a failure' {
        $result = Invoke-ProgressSteps -Title 'T' -Items 'a' -Action { param($i) throw 'x' } -Mode Plain 6>$null

        Get-ProgressExitCode $result | Should -Be 1
    }

    It 'returns an integer' {
        (Get-ProgressExitCode $null) | Should -BeOfType ([int])
        (Get-ProgressExitCode ([pscustomobject]@{ Failed = @() })) | Should -BeOfType ([int])
    }
}