function Format-Summary {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [int]$Done,

        [Parameter(Mandatory)]
        [int]$Present,

        [Parameter(Mandatory)]
        [ValidateSet('Installed', 'Updated')]
        [string]$Verb,

        [Parameter(Mandatory)]
        [timespan]$Elapsed
    )

    $verbText = $Verb.ToLowerInvariant()

    if ($Done -gt 0 -and $Present -gt 0) { return "✓ $Done $verbText, $Present already present" }
    if ($Done -gt 0) { return "✓ $Done $verbText in $(Format-Elapsed $Elapsed)" }
    if ($Present -gt 0) { return "✓ $Present already present" }

    ''
}
