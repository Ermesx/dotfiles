BeforeDiscovery {
    $defaults = Get-Content -Path "C:\dotfiles\common\defaults.json" | ConvertFrom-Json
    $fonts = $defaults.fonts

    $fontUrl = $fonts.sourceUrl
    $zipPath = "$env:TEMP\$(Split-Path -Path $fontUrl -Leaf)"
    $extractPath = "$env:TEMP\fonts"

    if (-Not (Test-Path -Path $zipPath) -Or -Not (Test-Path -Path $extractPath)) {
        Invoke-WebRequest -Uri $fontUrl -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    }
}

Describe "Font Installation Tests" {
    BeforeAll {
        $fontRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        $installedFonts = Get-ItemProperty -Path $fontRegistryPath

        $extractedFontFiles = Get-ChildItem -Path "$env:TEMP\fonts" -Recurse -Include *.ttf, *.otf     
    }
    
    It "should have the font '<_.BaseName>' registered in the registry" -ForEach $extractedFontFiles {
        $fontName = "$($_.BaseName) (TrueType)"
        $installedFonts.PSObject.Properties.Name -contains "$fontName" | Should -BeTrue
    }

    It "should have the font file '<_.Name>' present in the Fonts directory" -ForEach $extractedFontFiles {
        $fontPath = Join-Path -Path "$env:WINDIR\Fonts" -ChildPath $_.Name
        Test-Path $fontPath | Should -BeTrue
    }
}
