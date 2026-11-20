function Update-Modules {
    param(
        [hashtable]$Declared = $Global:PackageUpdatesDeclared
    )

    Write-Cyan -Text '► Updating Modules'
    $rows = @(Get-ModuleUpdates -Names $Declared.Modules)
    Invoke-PackageUpdateLoop -Rows $rows -Kind 'module' -Section Modules -Update {
        param($name)
        # A standard user cannot write the AllUsers scope
        Update-Module -Name $name -Scope CurrentUser -Force -ErrorAction Stop
        $true
    }
}
