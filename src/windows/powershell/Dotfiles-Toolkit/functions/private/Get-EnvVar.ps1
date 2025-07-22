function Get-EnvVar {
    param (
        [string]$Name,
        [System.EnvironmentVariableTarget]$Scope
    )
    return [System.Environment]::GetEnvironmentVariable($Name, $Scope)
}