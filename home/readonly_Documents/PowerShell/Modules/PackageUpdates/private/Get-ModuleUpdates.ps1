function Get-ModuleUpdates {
    param(
        [string[]]$Names = @()
    )

    foreach ($name in $Names) {
        try {
            $installed = Get-InstalledModule -Name $name -ErrorAction Stop
            $latest = Find-Module -Name $name -ErrorAction Stop
        }
        catch {
            # Not installed, or not in the Gallery: nothing to update
            continue
        }
        if ([version]$latest.Version -gt [version]$installed.Version) {
            [pscustomobject]@{
                Name = $installed.Name
                Old = $installed.Version
                New = $latest.Version
            }
        }
    }
}
