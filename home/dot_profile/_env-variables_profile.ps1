$env:PATH = "$env:PATH;$env:ProgramFiles(x86)\GnuWin32\bin"
function Get-FlatContent {
    param (
        [string]$Path
    )
    $Path = Join-Path $HOME $Path
    if (Test-Path -Path $Path) {
        return ((Get-Content -Path $Path -Raw) -replace "[\r\n]+", " ").Trim()
    }
}

# Git comes from Scoop. This fragment loads first, so general_profile.ps1 reuses $gitRoot.
# Not `scoop prefix git`: spawning scoop at every shell start is slow.
$scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $HOME 'scoop' }
$gitRoot = Join-Path $scoopRoot 'apps\git\current'

# Initialize the yazi config env variables
$env:YAZI_FILE_ONE = Join-Path $gitRoot 'usr\bin\file.exe'

# Initialize the ripgrep config env variable
$env:RIPGREP_CONFIG_PATH = Join-Path $HOME ".config\.rgrc"

# Initialize the fzf config env variables
$env:FZF_DEFAULT_OPTS = Get-FlatContent ".config\fzf\fzf-default-opts"
$env:FZF_CTRL_T_OPTS = Get-FlatContent ".config\fzf\fzf-ctrlt-opts"
$env:FZF_CTRL_R_OPTS = Get-FlatContent ".config\fzf\fzf-ctrlr-opts"
$env:FZF_ALT_C_OPTS = Get-FlatContent ".config\fzf\fzf-altc-opts"

$env:FZF_DEFAULT_COMMAND = Get-FlatContent ".config\fzf\fzf-default-command"
$env:FZF_CTRL_T_COMMAND = Get-FlatContent ".config\fzf\fzf-default-command"
$env:FZF_ALT_C_COMMAND = (Get-FlatContent ".config\fzf\fzf-default-command").Replace('--type f', '--type d')

# Set bash to run scripts from fzf (examples and knowns konfigs is writen in bash)
$env:SHELL = Join-Path $gitRoot 'bin\bash.exe'

# fzf in zoxide
$env:_ZO_FZF_OPTS = Get-FlatContent ".config\fzf\fzf-zi-opts"
