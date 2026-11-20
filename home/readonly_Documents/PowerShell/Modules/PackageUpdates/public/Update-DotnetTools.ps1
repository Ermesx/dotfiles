function Update-DotnetTools {
    param(
        [hashtable]$Declared = $Global:PackageUpdatesDeclared
    )

    Write-Cyan -Text '► Updating .NET tools'
    $rows = @(Get-DotnetToolUpdates -Ids $Declared.DotnetTools)
    Invoke-PackageUpdateLoop -Rows $rows -Kind '.NET tool' -Section DotnetTools -Update {
        param($name)
        $global:LASTEXITCODE = 0
        dotnet tool update -g $name
        $LASTEXITCODE -eq 0
    }
}
