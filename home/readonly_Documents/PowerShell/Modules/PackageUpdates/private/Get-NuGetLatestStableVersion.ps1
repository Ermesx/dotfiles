function Get-NuGetLatestStableVersion {
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    try {
        $index = Invoke-RestMethod -Uri "https://api.nuget.org/v3-flatcontainer/$($Id.ToLowerInvariant())/index.json" -ErrorAction Stop
    }
    catch {
        return
    }
    $index.versions |
        Where-Object { $_ -notmatch '-' } |
        ForEach-Object { [version]$_ } |
        Sort-Object -Descending |
        Select-Object -First 1
}
