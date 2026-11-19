# Pick up what Scoop wrote to the user registry (PATH, env_set variables) during this apply
foreach ($entry in [Environment]::GetEnvironmentVariables('User').GetEnumerator()) {
    Set-Item -Path "Env:$($entry.Key)" -Value $entry.Value
}
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
$machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
$env:PATH = "$userPath;$machinePath"
