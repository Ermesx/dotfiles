#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }, Write-Pretty

Describe 'Write-Pretty' {

    BeforeAll {
        Import-Module Write-Pretty -Force
        # Tests fake the PowerShell version by mutating the session-wide $PSVersionTable
        $script:originalPSVersion = $PSVersionTable.PSVersion
    }

    AfterEach {
        $PSVersionTable.PSVersion = $script:originalPSVersion
    }

    InModuleScope Write-Pretty {

        Context 'Basic Markdown parsing' {
            It 'renders bold, italic and underline in PS7' {
                Mock Write-Host { }

                $PSVersionTable.PSVersion = [version]'7.0.0'
                Write-Pretty '**Bold** _Italic_ __Underline__'

                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                    $Object -match "`e\[1mBold`e\[22m" -and
                        $Object -match "`e\[3mItalic`e\[23m" -and
                        $Object -match "`e\[4mUnderline`e\[24m"
                }
            }

            It 'strips markdown in PS5' {
                Mock Write-Host { }

                $PSVersionTable.PSVersion = [version]'5.1.0'
                Write-Pretty '**Bold** _Italic_ __Underline__' -FallbackForegroundColor 'Yellow'

                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                    $Object -eq 'Bold Italic Underline' -and
                        $ForegroundColor -eq 'Yellow'
                }
            }
        }

        Context 'ANSI RGB colors in PS7' {
            It 'includes correct ANSI sequences for RGB' {
                Mock Write-Host { }

                $PSVersionTable.PSVersion = [version]'7.0.0'
                Write-Pretty 'Color test' -ForegroundColor '255,128,64' -BackgroundColor '0,64,128'

                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                    $Object -match "`e\[38;2;255;128;64m" -and
                        $Object -match "`e\[48;2;0;64;128m"
                }
            }
        }

        Context 'Fallback colors in PS5' {
            It 'uses fallback colors' {
                Mock Write-Host { }

                $PSVersionTable.PSVersion = [version]'5.1.0'
                Write-Pretty 'Simple text' -FallbackForegroundColor 'Green' -FallbackBackgroundColor 'Black'

                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                    $ForegroundColor -eq 'Green' -and
                        $BackgroundColor -eq 'Black'
                }
            }
        }

        Context 'NoNewline behavior' {
            It 'passes -NoNewline when set' {
                Mock Write-Host { }

                $PSVersionTable.PSVersion = [version]'7.0.0'
                Write-Pretty 'Line test' -NoNewline

                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                    $NoNewline -eq $true
                }
            }
        }

        # Write-PrettyTable calls `Write-Host $line` positionally; Write-Host binds -Object with
        # ValueFromRemainingArguments, so $Object is a List[object], not a string. Compare "$Object".
        Context 'Write-PrettyTable' {
            It 'renders objects from the pipeline as a bordered table' {
                Mock Write-Host { }
                $data = @(
                    [pscustomobject]@{ Name = 'Alice'; Age = 30 },
                    [pscustomobject]@{ Name = 'Bob'; Age = 25 }
                )

                $data | Write-PrettyTable

                Should -Invoke Write-Host -Times 3 -Exactly -ParameterFilter { "$Object" -eq '+-------+-----+' }
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -eq '| Alice | 30  |' }
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -eq '| Bob   | 25  |' }
            }

            It 'renders an array passed as a single argument' {
                Mock Write-Host { }
                $data = @(
                    [pscustomobject]@{ Name = 'Carol'; Age = 40 },
                    [pscustomobject]@{ Name = 'Dave'; Age = 22 }
                )

                Write-PrettyTable -Data $data

                Should -Invoke Write-Host -Times 3 -Exactly -ParameterFilter { "$Object" -eq '+-------+-----+' }
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -eq '| Carol | 40  |' }
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -eq '| Dave  | 22  |' }
            }

            It 'renders hashtables from the pipeline' {
                Mock Write-Host { }
                $data = @(
                    @{ Name = 'Eve'; Age = 28 },
                    @{ Name = 'Frank'; Age = 33 }
                )

                $data | Write-PrettyTable

                # Hashtable key order is not guaranteed, so accept either column order
                Should -Invoke Write-Host -Times 3 -Exactly -ParameterFilter { "$Object" -match '^\+(-------\+-----|-----\+-------)\+$' }
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -match '^\| (Eve   \| 28  |28  \| Eve   )\|$' }
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -match '^\| (Frank \| 33  |33  \| Frank )\|$' }
            }

            It 'writes nothing for empty input' {
                Mock Write-Host { }

                @() | Write-PrettyTable

                Should -Invoke Write-Host -Times 0 -Exactly
            }

            It 'skips null rows' {
                Mock Write-Host { }

                Write-PrettyTable -Data @($null, [pscustomobject]@{ Name = 'Gina'; Age = 51 }, $null)

                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -eq '| Gina | 51  |' }
                Should -Invoke Write-Host -Times 3 -Exactly -ParameterFilter { "$Object" -eq '+------+-----+' }
            }
        }
    }
}
