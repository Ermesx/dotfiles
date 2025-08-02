function Write-Pretty {
<#
.SYNOPSIS
Displays text with Markdown support and colors in the PowerShell console.

.DESCRIPTION
The `Write-Pretty` function allows you to display text with Markdown formatting (bold, underline, italic) and colors (RGB or default) in the PowerShell console. Works in both PowerShell 7+ (ANSI) and older versions (Write-Host fallback).

.PARAMETER Text
Text to display. Supports Markdown: **bold**, _italic_, __underline__.

.PARAMETER NoNewLine
If set, does not add a new line after the text.

.PARAMETER ForegroundColor
Text color in "R,G,B" format (PowerShell 7+ only).

.PARAMETER BackgroundColor
Background color in "R,G,B" format (PowerShell 7+ only).

.PARAMETER FallbackForegroundColor
Text color for older PowerShell versions.

.PARAMETER FallbackBackgroundColor
Background color for older PowerShell versions.

.EXAMPLE
Write-Pretty -Text "**Hello** _world_" -ForegroundColor "255,0,0"

#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Text,

        [switch]$NoNewLine,

        [string]$ForegroundColor,
        [string]$BackgroundColor,

        [string]$FallbackForegroundColor,
        [string]$FallbackBackgroundColor
    )

    begin {
        $isPS7 = $PSVersionTable.PSVersion.Major -ge 7

        function Convert-MarkdownToAnsi {
            param([string]$Text)
            $Text -replace '\*\*(.+?)\*\*', "`e[1m`$1`e[22m" `
                 -replace '__(.+?)__', "`e[4m`$1`e[24m" `
                 -replace '_([^_]+?)_', "`e[3m`$1`e[23m"
        }

        function Convert-ToAnsiCode {
            param(
                [string]$ColorString,
                [ValidateSet("fg", "bg")]
                [string]$Type
            )
            if ($ColorString -match '^\d{1,3},\d{1,3},\d{1,3}$') {
                $rgb = $ColorString -split ','
                if ($Type -eq 'fg') {
                    return "`e[38;2;$($rgb -join ';')m"
                } else {
                    return "`e[48;2;$($rgb -join ';')m"
                }
            }
            return ''
        }

        function Clean-Markdown {
            param([string]$Text)
            $Text -replace '\*\*(.+?)\*\*', '$1' `
                 -replace '__(.+?)__', '$1' `
                 -replace '_([^_]+?)_', '$1'
        }

        function Write-SafeHost {
            param (
                [string]$Content,
                [switch]$UseNoNewLine,
                [string]$FGColor,
                [string]$BGColor
            )
            $paramsForWriteHost = @{ Object = $Content }
            if ($UseNoNewLine) { $paramsForWriteHost['NoNewLine'] = $true }
            if ($FGColor) { $paramsForWriteHost['ForegroundColor'] = $FGColor }
            if ($BGColor) { $paramsForWriteHost['BackgroundColor'] = $BGColor }
            Write-Host @paramsForWriteHost
        }
    }

    process {
        if ($isPS7) {
            $ansiText = Convert-MarkdownToAnsi -Text $Text
            $ansiFG = Convert-ToAnsiCode -ColorString $ForegroundColor -Type 'fg'
            $ansiBG = Convert-ToAnsiCode -ColorString $BackgroundColor -Type 'bg'
            $reset = "`e[0m"
            $finalText = "$ansiFG$ansiBG$ansiText$reset"
            Write-SafeHost -Content $finalText -UseNoNewLine:$NoNewLine
        } else {
            $plainText = Clean-Markdown -Text $Text
            Write-SafeHost -Content $plainText -UseNoNewLine:$NoNewLine `
                -FGColor $FallbackForegroundColor -BGColor $FallbackBackgroundColor
        }
    }
}
