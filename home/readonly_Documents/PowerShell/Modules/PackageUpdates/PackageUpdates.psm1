# One cache shared by every session: the background refresh writes it, the commands read it
$script:CacheFile = Join-Path $env:TEMP 'PackageUpdatesCache.json'
$script:MaxCacheAge = [TimeSpan]::FromHours(4)

# Load all functions
Get-ChildItem -Path "$PSScriptRoot\private" -Recurse -Filter *.ps1 | ForEach-Object { . $_.FullName }
Get-ChildItem -Path "$PSScriptRoot\public" -Recurse -Filter *.ps1 | ForEach-Object { . $_.FullName }

# Export only public functions
$publicFunctions = Get-Command -CommandType Function |
    Where-Object { $_.ScriptBlock.File -like "$PSScriptRoot\public*" } |
    Select-Object -ExpandProperty Name

Export-ModuleMember -Function $publicFunctions
