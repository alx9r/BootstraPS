Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

Describe enumerations {
    It 'use' {
        [BootstraPS.Schannel.Ciphers]::AES_128_128
    }
}