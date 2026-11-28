function Format-Elapsed {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [timespan]$Span
    )

    # Invariant culture: the decimal separator must not follow the host locale
    if ($Span.TotalSeconds -lt 60) {
        return $Span.TotalSeconds.ToString('0.0', [cultureinfo]::InvariantCulture) + 's'
    }

    '{0}m {1}s' -f [int][math]::Floor($Span.TotalMinutes), $Span.Seconds
}
