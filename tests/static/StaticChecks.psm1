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

# A decrypt call: the template function inside {{ … }}, or the CLI (`chezmoi age decrypt`) in a script.
# The bare word is not enough: file names and comments mention decrypt scripts without decrypting anything.
$script:TemplateDecrypt = '\{\{[^}]*\bdecrypt\b'
$script:AnyDecrypt = "$script:TemplateDecrypt|\bage\s+decrypt\b"

function Get-CiDecryptionViolation {
    param([Parameter(Mandatory)] [string]$Source)

    $root = Get-SourceRoot $Source

    # chezmoi's own files are not targets, yet CI renders them: config template, data, externals, ignore files,
    # shared templates. Scripts are covered below (only the CI-ignored ones may decrypt).
    $violations = @(Get-ChildItem $root -Recurse -File -Force |
        ForEach-Object { [IO.Path]::GetRelativePath($root, $_.FullName) -replace '\\', '/' } |
        Where-Object { $_ -match '(^|/)\.chezmoi' -and $_ -notlike '.chezmoiscripts/*' } |
        Where-Object { Select-String -Path (Join-Path $root $_) -Pattern $script:AnyDecrypt -Quiet })

    try {
        $managed = Get-ManagedPath $Source -SourceRelative
    } catch {
        # Listing targets renders externals and ignore files; a decrypt there fails without a key.
        # That failure is the violation already found above.
        if ($violations) { return @($violations) | Sort-Object -Unique }
        throw
    }

    $violations += foreach ($path in $managed) {
        if ((Split-Path $path -Leaf) -match 'encrypted_') { $path; continue }
        # Any file, not only templates: a plain script can run `chezmoi age decrypt` too
        $file = Join-Path $root $path
        if ((Test-Path $file -PathType Leaf) -and (Select-String -Path $file -Pattern $script:AnyDecrypt -Quiet)) { $path }
    }
    @($violations) | Sort-Object -Unique
}

function Get-CiIgnoredTarget {
    param([Parameter(Mandatory)] [string]$Source)

    $withCi = Get-ManagedPath $Source
    Get-ManagedPath $Source -NoCi | Where-Object { $_ -notin $withCi } | Sort-Object
}

function Get-TemplateRenderFailure {
    param([Parameter(Mandatory)] [string]$Source)

    $root = Get-SourceRoot $Source
    foreach ($file in Get-ChildItem $root -Recurse -File -Force) {
        $path = [IO.Path]::GetRelativePath($root, $file.FullName) -replace '\\', '/'
        # Every template, managed or ignored in CI: an ignored one still runs on a real machine
        $isTemplate = $file.Name -like '*.tmpl' -or $file.Name -eq '.chezmoiignore' -or $path -like '.chezmoitemplates/*'
        if (-not $isTemplate) { continue }
        # Templates that decrypt are kept out of CI by the guard; rendering them here would need the key
        if (Select-String -Path $file.FullName -Pattern $script:TemplateDecrypt -Quiet) { continue }

        $arguments = @('execute-template')
        if ($path -eq '.chezmoi.toml.tmpl') { $arguments += '--init' }
        $result = Invoke-ChezmoiCi -Source $Source -Arguments $arguments -InputText ([string](Get-Content -Raw $file.FullName))
        if ($result.ExitCode -ne 0) {
            [pscustomobject]@{ Path = $path; Error = $result.Error }
        }
    }
}

function Get-PackagesData {
    param([Parameter(Mandatory)] [string]$Source)

    $result = Invoke-ChezmoiCi -Source $Source -Arguments @('data', '--format', 'json')
    if ($result.ExitCode -ne 0) { throw "chezmoi data failed: $($result.Error)" }
    ($result.Output -join "`n" | ConvertFrom-Json).packages
}

# Methods each platform may use (header of home/.chezmoidata/packages.yaml)
$script:AllowedMethods = @{
    global  = @('dotnet_tools', 'yazi_plugins')
    windows = @('scoop', 'modules', 'wsl')
    linux   = @('brew', 'zsh_plugins')
}

function Get-PackagesSchemaProblem {
    param([Parameter(Mandatory)] [object]$Packages)

    foreach ($platform in $Packages.PSObject.Properties) {
        if ($platform.Name -notin $script:AllowedMethods.Keys) { "unknown platform '$($platform.Name)'"; continue }
        # Without a profiles mapping the install scripts render nothing for the platform, silently
        if ($platform.Value.profiles -isnot [pscustomobject]) {
            "$($platform.Name): 'profiles' is missing or not a mapping"
        }

        foreach ($key in $platform.Value.PSObject.Properties) {
            if ($key.Name -ne 'profiles') { "$($platform.Name): unknown key '$($key.Name)', only 'profiles'"; continue }

            foreach ($packageProfile in $key.Value.PSObject.Properties) {
                $where = "$($platform.Name).profiles.$($packageProfile.Name)"
                if ($packageProfile.Value -isnot [pscustomobject]) {
                    "${where}: not a profile ('pick' belongs on a profile)"
                    continue
                }

                foreach ($entry in $packageProfile.Value.PSObject.Properties) {
                    $at = "$where.$($entry.Name)"
                    if ($entry.Name -eq 'pick') {
                        if ($entry.Value -isnot [bool]) { "${at}: must be true or false" }
                    } elseif ($entry.Name -notin $script:AllowedMethods[$platform.Name]) {
                        "${at}: method not allowed on $($platform.Name)"
                    } elseif ($entry.Name -eq 'wsl') {
                        if ($entry.Value -isnot [string]) { "${at}: must be one distro name" }
                    } elseif ($entry.Value -isnot [array] -or @($entry.Value | Where-Object { $_ -isnot [string] }).Count) {
                        "${at}: must be a list of names"
                    }
                }
            }
        }
    }
}

function Get-ScoopItemProblem {
    param(
        [Parameter(Mandatory)] [string[]]$Item,
        # Bucket name -> GitHub URL; defaults to the buckets `scoop bucket add <name>` knows
        [hashtable]$KnownBucket
    )

    if (-not $KnownBucket) {
        $KnownBucket = @{}
        $known = Invoke-RestMethod 'https://raw.githubusercontent.com/ScoopInstaller/Scoop/master/buckets.json'
        $known.PSObject.Properties | ForEach-Object { $KnownBucket[$_.Name] = $_.Value }
    }

    foreach ($entry in $Item) {
        # An item without a bucket prefix comes from main
        $bucket, $app = if ($entry -match '/') { $entry -split '/', 2 } else { 'main', $entry }
        if (-not $KnownBucket.ContainsKey($bucket)) {
            [pscustomobject]@{ Item = $entry; Problem = 'unknown bucket' }
            continue
        }

        $repo = ([uri]$KnownBucket[$bucket]).AbsolutePath.Trim('/')
        $url = "https://raw.githubusercontent.com/$repo/HEAD/bucket/$app.json"
        # Only 404 means the package is missing; anything else is the network and is retried
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            try { $status = [int](Invoke-WebRequest -Uri $url -Method Head -SkipHttpErrorCheck).StatusCode }
            catch { $status = $_.Exception.Message }
            if ($status -in 200, 404) { break }
            if ($attempt -lt 3) { Start-Sleep -Seconds 2 }
        }

        if ($status -eq 404) {
            [pscustomobject]@{ Item = $entry; Problem = 'no manifest' }
        } elseif ($status -ne 200) {
            [pscustomobject]@{ Item = $entry; Problem = "network error $status" }
        }
    }
}

function Get-BrokenMarkdownLink {
    param([Parameter(Mandatory)] [string]$Path)

    $folder = Split-Path (Resolve-Path $Path)
    foreach ($match in [regex]::Matches((Get-Content -Raw $Path), '\]\(([^)\s]+)\)')) {
        $target = $match.Groups[1].Value
        # Only relative file links; web links and in-page anchors are out of scope
        if ($target -match '^(https?:|mailto:|#)') { continue }
        $file = ($target -split '#')[0]
        if (-not (Test-Path (Join-Path $folder $file))) { $target }
    }
}

Export-ModuleMember -Function Get-*Violation, Get-CiIgnoredTarget, Get-TemplateRenderFailure, Get-Packages*, Get-ScoopItemProblem, Get-BrokenMarkdownLink
