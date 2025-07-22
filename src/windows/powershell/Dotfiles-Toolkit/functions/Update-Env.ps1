function Update-Env {
<#
.SYNOPSIS
    Updates the PATH environment variable by appending additional valid paths.

.DESCRIPTION
    The `Update-Env` function retrieves the current PATH environment variable values from both the machine and user scopes. It allows appending additional valid paths provided as input. Invalid paths are ignored, and verbose output is provided for debugging.

.PARAMETER AdditionalPath
    A semicolon-separated string of additional paths to append to the PATH environment variable. Only valid paths are added.

.EXAMPLE
Update-Env -AdditionalPath "C:\NewPath;D:\AnotherPath"
    Appends `C:\NewPath` and `D:\AnotherPath` to the PATH environment variable if they are valid.
#>

    [CmdletBinding()]
    param (
        [string]$AdditionalPath = ""
    )

    Write-Verbose "Previous PATH value: $env:Path"

    $userPath = Get-EnvVar -Name "Path" -Scope ([System.EnvironmentVariableTarget]::User)

    if ($AdditionalPath -and $AdditionalPath.Trim() -ne "") {
        $validPaths = @()
        $invalidPaths = @()
        $allPaths = $AdditionalPath -split ";" | Where-Object { $_.Trim() -ne "" }
        $userPaths = $userPath -split ";" | Where-Object { $_.Trim() -ne "" }

        foreach ($path in $allPaths) {
            if ((Test-Path $path) -and -not ($userPaths.Contains($path))) {
                $validPaths += $path
            }
            else {
                $invalidPaths += $path
            }
        }

        if ($invalidPaths.Count -gt 0) {
            Write-Verbose "Incorrect PATH values: $($invalidPaths -join ';')"
        }

        if ($validPaths.Count -gt 0) {
            Write-Verbose "Additional PATH values: $($validPaths -join ';')"
            $userPath = ($userPaths -join ";") + ";" + ($validPaths -join ";")
            Set-EnvVar -Name "Path" -Value $userPath -Scope ([System.EnvironmentVariableTarget]::User)
        }
    }

    $machinePath = Get-EnvVar -Name "Path" -Scope ([System.EnvironmentVariableTarget]::Machine)
    $newPath = $machinePath + ";" + $userPath
    Write-Verbose "New PATH value: $newPath"

    $env:Path = $newPath
    Write-Host "🔄 PATH environment variable refreshed."
}