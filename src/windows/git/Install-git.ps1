# Install Git for Windows and posh-git module

Install-OrUpdateApp -AppId "Git.Git" -UpdateEnv -Command "git"
Install-OrUpdateApp -AppId "Git.GCM"
Install-OrUpdateModule -ModuleName posh-git

Add-ToProfile -Comment "Import posh-git" -ScriptBlock {
    Import-Module posh-git
}

# TODO: Check if below commands have modules instead of apps

# Install or upgrade lazygit - console git UI
Install-OrUpdateApp -AppId "JesseDuffield.lazygit" -UpdateEnv -Command "lazygit"

# Install or upgrade gitql - git query language like SQL
Install-OrUpdateApp -AppId "amrdeveloper.gitql" -UpdateEnv -Command "gitql"

# Install or upgrade onefetch - git repository nerdy statistics
Install-OrUpdateApp -AppId "o2sh.onefetch" -UpdateEnv -Command "onefetch"

Add-ToProfile -Comment "Load git repository greeter when enter a git repository" `
              -Path "$PSScriptRoot\git-repository-greeter.ps1"

# Install git configuration



# Interesting Tools
# pre-commit - check hooks before commit
# gitleaks - check for secrets before commit
# gitVersion - manage aplication versioning cli, pipelines, docker, build
