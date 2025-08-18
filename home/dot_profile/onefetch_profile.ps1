# git repository greeter
$Global:lastRepository = $null

function Test-DirectoryForNewRepository {
    $currentRepository = git rev-parse --show-toplevel 2>$null
    if ($currentRepository -and ($currentRepository -ne $Global:lastRepository)) {
        Write-Host
        onefetch --nerd-fonts
        $Global:lastRepository = $currentRepository
    }
}

Register-EngineEvent ChangeDirectory -Action { Test-DirectoryForNewRepository } | Out-Null

# Override the Set-Location command to check for a new repository
function Set-Location {
    Microsoft.PowerShell.Management\Set-Location @args
    New-Event -SourceIdentifier ChangeDirectory | Out-Null
}

# Check the repository also when opening a shell directly in a repository directory
Test-DirectoryForNewRepository