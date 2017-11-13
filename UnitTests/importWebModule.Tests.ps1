Get-Module BootstraPS | Remove-Module
Import-Module "$PSScriptRoot\..\BootstraPS.psm1"

InModuleScope BootstraPS {
Describe 'Import-WebModule' {
    Mock Save-WebFile -Verifiable
    Mock Get-Item
    Mock Expand-WebModule
    It 'passes through security arguments' {
        Import-WebModule 'http://uri' -CertificateValidator {validator} -SecurityPolicy Strict
        Assert-MockCalled Save-WebFile 1 -Exactly {
            [string]$CertificateValidator -eq 'validator' -and
            $SecurityPolicy -eq 'Strict'
        }
    }
}
}