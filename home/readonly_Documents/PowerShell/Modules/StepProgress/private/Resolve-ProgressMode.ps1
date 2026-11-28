function Resolve-ProgressMode {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Auto', 'Live', 'Plain')]
        [string]$Mode
    )

    if ($Mode -ne 'Auto') { return $Mode }

    # A live line only makes sense on a terminal a person is watching; logs and CI get plain lines
    if ($env:CI -eq 'true' -or [Console]::IsOutputRedirected) { return 'Plain' }

    'Live'
}
