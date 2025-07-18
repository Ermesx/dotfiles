# Install Docker
Install-OrUpdateApp -AppId "Docker.DockerDesktop" -UpdateEnv -Command "docker"

# Install or update Docker completion module
Install-OrUpdateModule -ModuleName DockerCompletion

Add-ToProfile -Comment "Import DockerCompletion" -ScriptBlock {
    Import-Module DockerCompletion
} 