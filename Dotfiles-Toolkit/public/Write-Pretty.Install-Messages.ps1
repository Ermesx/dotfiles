function Write-Install {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Label,
        [version] $Version,
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [scriptblock] $Script
    )
    
    $Pad = Get-PadLength -Text $Label
    
    Write-Cyan "🌀 Installing " -NoNewline
    Write-Pretty "__$($Label)__$Pad" -NoNewline

    & $Script

    Write-Green "`r✅ [OK]   " -NoNewline
    Write-Pretty "__$($Label)__$Pad" -NoNewline
    
    if ($Version) {
        Write-Yellow "($Version)"
    } else {
        Write-Host
    }    
}

function Write-Upgrade {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Label,
        [Parameter(Mandatory)] [version] $FromVersion,
        [Parameter(Mandatory)] [version] $ToVersion,
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [scriptblock] $Script
    )
    
    $Pad = Get-PadLength -Text $Label
    
    Write-Cyan "🌀 Upgrading " -NoNewline
    Write-Pretty "__$($Label)__$Pad" -NoNewline
    Write-Host "($FromVersion" -ForegroundColor Cyan -NoNewline
    Write-Red " => " -NoNewline
    Write-Yellow "$ToVersion" -NoNewline
    Write-Host ")" -ForegroundColor Cyan -NoNewline

    & $Script

    Write-Green "`r🔄 [OK]   " -NoNewline
    Write-Pretty "__$($Label)__$Pad" -NoNewline
    Write-Host "($FromVersion" -ForegroundColor Cyan -NoNewline
    Write-Red " => " -NoNewline
    Write-Yellow "$ToVersion" -NoNewline
    Write-Host ")" -ForegroundColor Cyan
}

function Write-Skip {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Label,
        [Parameter(Mandatory)] [version] $Version
    )
    
    $Pad = Get-PadLength -Text $Label
    
    Write-Yellow "👌 [Skip] " -NoNewline
    Write-Pretty "__$($Label)__$Pad" -NoNewline
    Write-Host "($Version)" -ForegroundColor Yellow
}
