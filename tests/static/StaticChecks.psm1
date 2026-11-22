# Static checks of the chezmoi source: run on the host and in CI, never decrypt anything.
# Every chezmoi call goes through Invoke-ChezmoiCi, which points chezmoi at a config whose age identity does not
# exist: a decrypt fails instead of using the host's key.

$script:NoKeyConfig = $null

function Get-NoKeyConfig {
    if (-not $script:NoKeyConfig) {
        $dir = Join-Path ([IO.Path]::GetTempPath()) "dotfiles-static-$PID"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $path = Join-Path $dir 'chezmoi.toml'
        # TOML literal strings ('...') keep Windows backslashes as they are
        @(
            'encryption = "age"'
            '[age]'
            "identity = '$(Join-Path $dir 'no-such-key.txt')'"
            'recipient = "age1xvez3je4mhx7xswxu6gpalmrxq88uktcncthtqs8m7zcjgnjd4qsq05uw8"'
            '[warnings]'
            'configFileTemplateHasChanged = false'
        ) | Set-Content -Path $path
        $script:NoKeyConfig = $path
    }
    $script:NoKeyConfig
}

function Invoke-ChezmoiCi {
    param(
        [Parameter(Mandatory)] [string]$Source,
        [Parameter(Mandatory)] [string[]]$Arguments,
        [string]$InputText,
        [switch]$NoCi
    )

    $chezmoiArgs = @('--config', (Get-NoKeyConfig), '--source', $Source) + $Arguments
    $previous = $env:CI
    try {
        # GitHub sets CI for the whole job, so "without CI" has to remove it, not just leave it alone
        if ($NoCi) { Remove-Item Env:CI -ErrorAction SilentlyContinue } else { $env:CI = 'true' }

        $all = if ($PSBoundParameters.ContainsKey('InputText')) {
            $InputText | & chezmoi @chezmoiArgs 2>&1
        } else {
            & chezmoi @chezmoiArgs 2>&1
        }
        $exitCode = $LASTEXITCODE
    } finally {
        $env:CI = $previous
    }

    $isError = { $_ -is [System.Management.Automation.ErrorRecord] }
    [pscustomobject]@{
        Output   = @($all | Where-Object { -not (& $isError) } | ForEach-Object { "$_" })
        Error    = ($all | Where-Object $isError | ForEach-Object { "$_" }) -join "`n"
        ExitCode = $exitCode
    }
}

function Get-SourceRoot([string]$Source) {
    $marker = Join-Path $Source '.chezmoiroot'
    if (Test-Path $marker) { Join-Path $Source (Get-Content -Raw $marker).Trim() } else { $Source }
}

function Get-ManagedPath([string]$Source, [switch]$NoCi, [switch]$SourceRelative) {
    $arguments = @('managed', '--include=files,scripts,symlinks')
    if ($SourceRelative) { $arguments += @('--path-style', 'source-relative') }
    $result = Invoke-ChezmoiCi -Source $Source -Arguments $arguments -NoCi:$NoCi
    if ($result.ExitCode -ne 0) { throw "chezmoi managed failed: $($result.Error)" }
    $result.Output
}

function Get-CiDecryptionViolation {
    param([Parameter(Mandatory)] [string]$Source)

    $root = Get-SourceRoot $Source
    $violations = foreach ($path in (Get-ManagedPath $Source -SourceRelative)) {
        if ((Split-Path $path -Leaf) -match 'encrypted_') { $path; continue }
        # Any file, not only templates: a plain script can run `chezmoi age decrypt` too
        $file = Join-Path $root $path
        if ((Test-Path $file -PathType Leaf) -and (Select-String -Path $file -Pattern '\bdecrypt\b' -Quiet)) { $path }
    }

    # Shared templates are not targets, but any target may include them
    $shared = Join-Path $root '.chezmoitemplates'
    if (Test-Path $shared) {
        $violations += Get-ChildItem $shared -File -Recurse |
            Where-Object { Select-String -Path $_.FullName -Pattern '\bdecrypt\b' -Quiet } |
            ForEach-Object { [IO.Path]::GetRelativePath($root, $_.FullName) -replace '\\', '/' }
    }
    @($violations) | Sort-Object -Unique
}

function Get-CiIgnoredTarget {
    param([Parameter(Mandatory)] [string]$Source)

    $withCi = Get-ManagedPath $Source
    Get-ManagedPath $Source -NoCi | Where-Object { $_ -notin $withCi } | Sort-Object
}

Export-ModuleMember -Function Get-*Violation, Get-CiIgnoredTarget
