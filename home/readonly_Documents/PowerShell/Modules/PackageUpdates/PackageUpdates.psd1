@{
    RootModule = 'PackageUpdates.psm1'
    ModuleVersion = '1.0.0'
    GUID = '07d079f8-bb55-4da2-9dfe-305321773318'
    Author = 'Wojciech Gadziński'
    Description = 'Checks and updates the Scoop apps, PowerShell modules and .NET tools declared in packages.yaml'
    PowerShellVersion = '7.0'
    RequiredModules = @('Write-Pretty')
    FunctionsToExport = '*'
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
