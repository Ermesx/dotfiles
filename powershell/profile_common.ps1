
# General variables
$profileRoot    = "$(split-path $profile)"
$scripts     	= "$profileRoot\Scripts"
$modules     	= "$profileRoot\Modules"
$configuration	= "$profileRoot\configuration"

# Include common functions
. $scripts\common-utils.ps1

$env:path += ";$profileRoot;$scripts"

set-alias ai assembly-info

# Configuring git
$gitInstallDir = Get-FolderInProgramFiles "Git"
if ($gitInstallDir -ne $null) {
    #$env:Path = "$env:Path;$gitInstallDir\bin;$gitInstallDir\mingw\bin"
	#$env:Path = "$env:Path;$gitInstallDir\mingw\bin"
    if(!$Env:HOME) { $env:HOME = "$env:HOMEDRIVE$env:HOMEPATH" }
    if(!$Env:HOME) { $env:HOME = $env:USERPROFILE }
    if(!$Env:GIT_HOME) { $env:GIT_HOME = "$gitInstallDir" }
    $env:PLINK_PROTOCOL = 'ssh'
}

# Import PowerTab
Import-Module "PowerTab" -ArgumentList "C:\repositories\dotfiles\powershell\PowerTabConfig.xml"

# Run posh-git init script
pushd
cd $modules\posh-git
Import-Module .\posh-git
Enable-GitColors
popd

# Run posh-rake init script
pushd
cd $modules\posh-rake
Import-Module .\posh-rake
popd

# Configure prompt
. $configuration\configure-ps-prompt.ps1

# Configure ssh-agent so git doesn't require a password on every push
. $scripts\ssh-agent-utils.ps1

# return all IP addresses
function get-ips() {
   $ent = [net.dns]::GetHostEntry([net.dns]::GetHostName())
   return $ent.AddressList | ?{ $_.ScopeId -ne 0 } | %{
      [string]$_
   }
}

# save last 100 history items on exit
$historyPath = Join-Path (split-path $profile) history.clixml
 
# hook powershell's exiting event & hide the registration with -supportevent.
Register-EngineEvent -SourceIdentifier powershell.exiting -SupportEvent -Action {
    Get-History -Count 20 | Export-Clixml (Join-Path (split-path $profile) history.clixml) }
 
# load previous history, if it exists
if ((Test-Path $historyPath)) {
    Import-Clixml $historyPath | ? {$count++;$true} | Add-History
    Write-Host -Fore Green "`nLoaded $count history item(s).`n"
}

. $profileRoot\Scripts\Set-ConsoleIcon.ps1

[GC]::Collect()
