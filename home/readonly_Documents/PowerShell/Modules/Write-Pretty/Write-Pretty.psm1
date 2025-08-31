# Load all functions
Get-ChildItem -Path "$PSScriptRoot\private" -Recurse -Filter *.ps1 | ForEach-Object { . $_.FullName }
Get-ChildItem -Path "$PSScriptRoot\public" -Recurse -Filter *.ps1 | ForEach-Object { . $_.FullName }

# Export only public functions
$publicFunctions = Get-Command -CommandType Function | 
                   Where-Object { $_.ScriptBlock.File -like "$PSScriptRoot\public*" } | 
                   Select-Object -ExpandProperty Name

Export-ModuleMember -Function $publicFunctions
