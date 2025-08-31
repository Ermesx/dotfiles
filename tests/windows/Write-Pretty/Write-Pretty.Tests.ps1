#Requires -Modules Pester, Write-Pretty

Describe 'Write-Pretty' {

    BeforeAll {
        Import-Module Write-Pretty -Force
    }
    
    InModuleScope Write-Pretty {

        Context 'Basic Markdown parsing' {
            It 'renders bold, italic and underline in PS7' {
                Mock Write-Host { }

                $PSVersionTable.PSVersion = [version]'7.0.0'
                Write-Pretty '**Bold** _Italic_ __Underline__'

                Assert-MockCalled Write-Host -Times 1 -Exactly -ParameterFilter {
                    $Object -match "`e\[1mBold`e\[22m" -and
                            $Object -match "`e\[3mItalic`e\[23m" -and
                            $Object -match "`e\[4mUnderline`e\[24m"
                }
            }

            It 'strips markdown in PS5' {
                Mock Write-Host { }

                $PSVersionTable.PSVersion = [version]'5.1.0'
                Write-Pretty '**Bold** _Italic_ __Underline__' -FallbackForegroundColor 'Yellow'

                Assert-MockCalled Write-Host -Times 1 -Exactly -ParameterFilter {
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

                Assert-MockCalled Write-Host -Times 1 -Exactly -ParameterFilter {
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

                Assert-MockCalled Write-Host -Times 1 -Exactly -ParameterFilter {
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

                Assert-MockCalled Write-Host -Times 1 -Exactly -ParameterFilter {
                    $NoNewline -eq $true
                }
            }
        }
    }
}
