# Load all functions, including those from the 'private' folder
Get-ChildItem -Path "$PSScriptRoot\functions" -Recurse -Filter *.ps1 | ForEach-Object { . $_.FullName }

# Export only functions outside the 'private' folder
$publicFunctions = Get-ChildItem "$PSScriptRoot\functions" -Recurse -Filter *.ps1 |
        Where-Object { $_.FullName -notmatch '\\private\\' } |
        ForEach-Object { $_.BaseName }

Export-ModuleMember -Function $publicFunctions
