
Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

Describe ScriptBlockInvoker {
    Context 'module' {
        It 'one module' {
            $sbi = [ScriptBlockInvoker]::new(
                {Get-7d4176b6},
                $null,
                $null,
                $null,
                $null,
                'BootstraPS'
            )
            $sbi.Invoke()

            $r = $sbi.ReturnValue

            $r | Should be 'Get-7d4176b6'
        }
    }
}
