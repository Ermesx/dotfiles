function Write-Pretty {
<#
.SYNOPSIS
Wyświetla tekst z obsługą Markdown i kolorami w konsoli PowerShell.

.DESCRIPTION
Funkcja `Write-Pretty` umożliwia wyświetlanie tekstu z formatowaniem Markdown (pogrubienie, podkreślenie, kursywa) oraz kolorami (RGB lub domyślne) w konsoli PowerShell. Działa zarówno w PowerShell 7+ (ANSI), jak i w starszych wersjach (Write-Host z fallbackiem).

.PARAMETER Text
Tekst do wyświetlenia. Obsługuje Markdown: **pogrubienie**, _kursywa_, __podkreślenie__.

.PARAMETER NoNewLine
Jeśli ustawione, nie dodaje nowej linii po tekście.

.PARAMETER ForegroundColor
Kolor tekstu w formacie "R,G,B" (tylko PowerShell 7+).

.PARAMETER BackgroundColor
Kolor tła w formacie "R,G,B" (tylko PowerShell 7+).

.PARAMETER FallbackForegroundColor
Kolor tekstu dla starszych wersji PowerShell.

.PARAMETER FallbackBackgroundColor
Kolor tła dla starszych wersji PowerShell.

.EXAMPLE
Write-Pretty -Text "**Witaj** _świecie_" -ForegroundColor "255,0,0"

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
