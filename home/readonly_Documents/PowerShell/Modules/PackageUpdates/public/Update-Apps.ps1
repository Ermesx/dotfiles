function Update-Apps {
    param(
        [hashtable]$Declared = $Global:PackageUpdatesDeclared
    )

    Write-Cyan -Text '► Updating Scoop and buckets'
    scoop update

    # Computed after `scoop update`, not taken from the cache, which may be hours old
    $rows = @(Get-ScoopAppUpdates -Names $Declared.Apps)
    Invoke-PackageUpdateLoop -Rows $rows -Kind 'app' -Section Apps -Update {
        param($name)
        # Scoop aborts with a non-zero exit code; it does not throw
        $global:LASTEXITCODE = 0
        scoop update $name
        $LASTEXITCODE -eq 0
    }
}
