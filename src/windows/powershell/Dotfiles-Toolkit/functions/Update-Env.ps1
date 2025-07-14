function Update-Env {
    [CmdletBinding()]
    param (
        [string]$AdditionalPath = ""
    )

    Write-Verbose "Previous PATH value: $env:Path"

    $newPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
   if ($AdditionalPath -and $AdditionalPath.Trim() -ne "") {
        $validPaths = @()
        $invalidPaths = @()
        $allPaths = $AdditionalPath -split ";" | Where-Object { $_.Trim() -ne "" }
        
        foreach ($path in $allPaths) {
            if (Test-Path $path.Trim()) {
                $validPaths += $path.Trim()
            } else {
                $invalidPaths += $path.Trim()
            }
        }
        
        if ($invalidPaths.Count -gt 0) {
            Write-Verbose "Incorrect PATH values: $($invalidPaths -join ';')"
        }
        
        if ($validPaths.Count -gt 0) {
            Write-Verbose "Additional PATH values: $($validPaths -join ';')"
            $newPath += ";" + ($validPaths -join ";")
        }
    }
        
    Write-Verbose "New PATH value: $newPath"
    
    $env:Path = $newPath
    Write-Host "PATH environment variable refreshed."
}