# Pick up what Scoop wrote to the user registry (PATH, env_set variables) during this apply
foreach ($entry in [Environment]::GetEnvironmentVariables('User').GetEnumerator()) {
    [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'Process')
}
$pathParts = 'User', 'Machine' | ForEach-Object { [Environment]::GetEnvironmentVariable('PATH', $_) } | Where-Object { $_ }
$env:PATH = $pathParts -join ';'
