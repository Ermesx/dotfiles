function Update-DotnetTools {
    # One tool at a time, not `dotnet tool update -g --all`: --all stops at the first tool that fails
    # (the SDK loop does not catch it), leaving the rest of the alphabet not updated
    Write-Cyan -Text '► Updating .NET tools'
    $rows = @(Get-DotnetToolUpdates)
    Invoke-PackageUpdateLoop -Rows $rows -Kind '.NET tool' -Section DotnetTools -Update {
        param($name)
        # Out-Host keeps dotnet's output out of the success result
        $global:LASTEXITCODE = 0
        dotnet tool update -g $name | Out-Host
        $LASTEXITCODE -eq 0
    }
}
