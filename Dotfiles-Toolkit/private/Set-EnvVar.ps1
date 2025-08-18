function Set-EnvVar {
    param (
        [string]$Name,
        [string]$Value,
        [System.EnvironmentVariableTarget]$Scope
    )
    [System.Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
}