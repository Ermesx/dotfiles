function Get-ProgressExitCode {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        # Not mandatory: a script whose Invoke-ProgressSteps never returned passes $null and must fail
        [object]$Result
    )

    # chezmoi stops the apply on a non-zero script exit, so a missing result counts as a failure
    [int]($null -eq $Result -or $Result.Failed.Count -gt 0)
}