# Local functions
function Test-InPath($fileName){
    $found = $false
    Find-InPath $fileName | %{$found = $true}

    return $found
}

function Find-InPath($fileName){
    $env:PATH.Split(';') | ?{!([System.String]::IsNullOrEmpty($_))} | %{
        if(Test-Path $_){
            ls $_ | ?{ $_.Name -like $fileName }
        }
    }
}

# General variables
$computer    = $env:computername
$profileRoot =  Split-Path $PROFILE
$scripts     = "$profileRoot\Scripts"
$modules     = "$profileRoot\Modules"

# Include common functions
. $scripts\common-utils.ps1

# Add to PATH when exists
$paths = $env:Path -split ';'
if ($paths -notcontains $profileRoot) { $env:Path += ";$profileRoot" }
if ($paths -notcontains $scripts) { $env:Path += ";$scripts" }

# Import PowerTab
pushd
cd $modules\power-tab
Import-Module .\PowerTab -ArgumentList "..\..\PowerTabConfig.xml"
popd

# Run posh-git init script
pushd
cd $modules\posh-git
# Load posh-git module from current directory
Import-Module .\posh-git
Enable-GitColors
popd

# Run posh-rake init script
pushd
cd $modules\posh-rake
# Load posh-rake module from current directory
Import-Module .\posh-rake
popd

# Configure prompt
. $profileRoot\configurePrompt.ps1

# Configure ssh-agent so git doesn't require a password on every push
if(Test-InPath ssh-agent.*){
    . $scripts\ssh-agent-utils.ps1
}else{
    Write-Error "ssh-agent cannot be found in your PATH, please add it"
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

# Set colors for ls
remove-item alias:ls
set-alias ls Get-ChildItemColor

function Get-ChildItemColor {
    $fore = $Host.UI.RawUI.ForegroundColor

    Invoke-Expression ("Get-ChildItem $args") |
    %{
      if ($_.GetType().Name -eq 'DirectoryInfo') {
        $Host.UI.RawUI.ForegroundColor = 'White'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
      } elseif ($_.Name -match '\.(zip|tar|gz|rar)$') {
        $Host.UI.RawUI.ForegroundColor = 'Blue'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
      } elseif ($_.Name -match '\.(exe|bat|cmd|py|pl|ps1|psm1|vbs|rb|reg)$') {
        $Host.UI.RawUI.ForegroundColor = 'Green'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
      } elseif ($_.Name -match '\.(txt|cfg|conf|ini|csv|sql|xml|config)$') {
        $Host.UI.RawUI.ForegroundColor = 'Cyan'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
      } elseif ($_.Name -match '\.(cs|asax|aspx.cs)$') {
        $Host.UI.RawUI.ForegroundColor = 'Yellow'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
       } elseif ($_.Name -match '\.(aspx|spark|master)$') {
        $Host.UI.RawUI.ForegroundColor = 'DarkYellow'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
       } elseif ($_.Name -match '\.(sln|csproj)$') {
        $Host.UI.RawUI.ForegroundColor = 'Magenta'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
       } elseif ($_.Name -match '\.(gitignore)$') {
	    $Host.UI.RawUI.ForegroundColor = 'DarkRed'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
	   }
        else {
        $Host.UI.RawUI.ForegroundColor = $fore
        echo $_
      }
    }
}

[GC]::Collect()
