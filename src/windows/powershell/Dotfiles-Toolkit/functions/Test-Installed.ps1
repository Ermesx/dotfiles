function Test-Installed {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Id
    )
    $result = winget list --id $Id
    
    Write-Verbose "Checking if package '$Id' is installed..."
    Write-Verbose "winget output:`n$result"
    
    return $null -ne ($result | Select-String $Id)
}