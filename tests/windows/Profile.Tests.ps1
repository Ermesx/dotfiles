#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Post-apply: the profile imports modules and calls tools that exist only after apply (CI and the VM)
Describe 'PowerShell profile' {

    It 'loads the PowerShell profile without errors' {
        # Error records written while loading, not $Error: SilentlyContinue probes record there on purpose
        $out = pwsh -NoLogo -NoProfile -Command '. $PROFILE' 2>&1
        $errors = @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })

        $LASTEXITCODE | Should -Be 0
        $errors | Should -BeNullOrEmpty -Because ($errors | Out-String)
    }
}
