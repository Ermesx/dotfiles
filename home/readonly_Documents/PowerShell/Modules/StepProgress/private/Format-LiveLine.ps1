function Format-LiveLine {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [int]$Index,

        [Parameter(Mandatory)]
        [int]$Total,

        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [int]$Width,

        # For consoles that cannot render the block characters
        [switch]$Ascii
    )

    $cells = 24
    $filled = [int][math]::Floor($cells * ($Index - 1) / $Total)
    $fullChar, $emptyChar, $ellipsis = if ($Ascii) { '#', '-', '~' } else { '█', '░', '…' }

    $line = ($fullChar * $filled) + ($emptyChar * ($cells - $filled)) + " $Index/$Total  $Text"

    # One column short of the window so the cursor never wraps onto a second line
    $max = $Width - 1
    if ($line.Length -gt $max) {
        $line = $line.Substring(0, $max - 1) + $ellipsis
    }

    $line
}
