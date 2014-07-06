
# General variables
$profileRoot    = "$(split-path $profile)"
$scripts     	= "$profileRoot\Scripts"
$configuration	= "$profileRoot\configuration"

# Configure PATH
. $configuration\configure-env-path.ps1

# Imports
Import-Module PowerTab -ArgumentList "C:\repositories\dotfiles\powershell\PowerTabConfig.xml"

Import-Module posh-git
Enable-GitColors

Import-Module posh-rake

# Configure prompt
. $configuration\configure-ps-prompt.ps1

# add function
. $scripts\git-most-changed.ps1

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
