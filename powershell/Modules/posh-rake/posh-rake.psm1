if (Get-Module posh-rake) { return }

Push-Location $psScriptRoot
. ./RakeTabExpansion.ps1
Pop-Location

Export-ModuleMember -Function @(
  'RakeTabExpansion'
)
