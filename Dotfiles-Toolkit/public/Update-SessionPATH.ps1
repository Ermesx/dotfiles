function Update-SessionPATH {
<#
.SYNOPSIS
    Updates the PATH environment variable by appending additional valid paths.

.DESCRIPTION
    The `Update-SessionPATH` function retrieves the current PATH environment variable values from both the machine and user scopes. It allows appending additional valid paths provided as input. Invalid paths are ignored, and verbose output is provided for debugging.

.PARAMETER AdditionalPath
    A semicolon-separated string of additional paths to append to the PATH environment variable. Only valid paths are added.

.EXAMPLE
    Update-SessionPATH -AdditionalPath "C:\NewPath;D:\AnotherPath"
    Appends `C:\NewPath` and `D:\AnotherPath` to the PATH environment variable if they are valid.
#>

    [CmdletBinding()]
    param (
        [string]$AdditionalPath = ""
    )

    Write-Verbose "Previous PATH value: $env:Path"
    $userPath = Get-EnvVar -Name "PATH" -Scope ([System.EnvironmentVariableTarget]::User)

    if ($AdditionalPath -and $AdditionalPath.Trim() -ne "") {
        $newPaths = "$userPath;$AdditionalPath" -split ";" | Select-Object { $_.Trim('\') } -Unique | Where-Object { Test-Path $_ }
        $userPath = $newPaths -join ";"
        
        Set-EnvVar -Name "Path" -Value $userPath -Scope ([System.EnvironmentVariableTarget]::User)
    }

    $machinePath = Get-EnvVar -Name "PATH" -Scope ([System.EnvironmentVariableTarget]::Machine)
    
    $newPath = "$machinePath;$userPath"
    Write-Verbose "New PATH value: $newPath"
    $env:Path = $newPath

    Write-Host "🔄 PATH environment variable refreshed."
}