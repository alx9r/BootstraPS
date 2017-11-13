Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

Describe CertificateValidator {
    It '$using:' {
        $a = 1
        $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new(
            {$using:a;$a},
            $null,
            (Get-Variable a)
        )
        $cv = [BootstraPS.Concurrency.CertificateValidator]::new(
            {$using:a;$a},
            $null,
            (Get-Variable a)
        )
        Out-Null
    }
}