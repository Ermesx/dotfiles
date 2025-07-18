# git repository greeter
$global:lastRepository = $null

function Test-DirectoryForNewRepository {
    $currentRepository = git rev-parse --show-toplevel 2>$null
    if ($currentRepository -and ($currentRepository -ne $global:lastRepository)) {
        onefetch | Write-Host
        $global:lastRepository = $currentRepository
    }
}

# Override the Set-Location command to check for a new repository
function Set-Location {
    Microsoft.PowerShell.Management\Set-Location @args
    Test-DirectoryForNewRepository
}

#Check the repository also when opening a shell directly in a repository directory
Test-DirectoryForNewRepository