function Update-DotnetTools {
    # One tool at a time, not `dotnet tool update -g --all`: --all stops at the first tool that fails
    # (the SDK loop does not catch it), leaving the rest of the alphabet not updated
    $rows = @(Get-DotnetToolUpdates)
    Invoke-PackageUpdateLoop -Rows $rows -Title 'Updating .NET tools' -Section DotnetTools -Update {
        param($name)
        dotnet tool update -g $name
    }
}
