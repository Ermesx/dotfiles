function Get-ScoopAppUpdates {
    param(
        [string[]]$Names = @()
    )

    # Scoop compares against the local bucket checkout; the caller runs `scoop update` first.
    # 6>$null drops Scoop's Write-Host messages, which the background refresh must not print.
    scoop status --local 6>$null |
        Where-Object {
            $_.PSObject.Properties['Latest Version'] -and
                $_.'Latest Version' -and
                $_.Info -notmatch 'Held package' -and
                $_.Name -in $Names
        } |
        ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                Old = $_.'Installed Version'
                New = $_.'Latest Version'
            }
        }
}
