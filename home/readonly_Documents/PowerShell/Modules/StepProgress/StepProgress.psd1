@{
    RootModule = 'StepProgress.psm1'
    ModuleVersion = '1.0.0'
    GUID = '5b0e6c1a-3f6d-4c52-9a41-7d2f8e0b9c64'
    Author = 'Wojciech Gadziński'
    Description = 'Runs a list of install or update steps and reports each one as a single progress line'
    PowerShellVersion = '7.0'
    RequiredModules = @()
    # Listed explicitly: the module is autoloaded on first use
    FunctionsToExport = @(
        'Invoke-ProgressSteps'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
