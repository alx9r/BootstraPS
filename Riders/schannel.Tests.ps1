Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

Describe 'Schannel configuration' {
    Context 'Ciphers' {
        It '<c> is disabled' -TestCases @(
            [BootstraPS.Schannel.Ciphers].GetEnumValues() | 
                ? {$_ -match 'RC4'} |
                % { @{c=$_} }
        ) {
            param($c)
            Assert-SchannelRegistryEntry Clear Enabled -Cipher $c
        }
    }
    Context 'Hashes' {
        It 'MD5 is disabled' {
            Assert-SchannelRegistryEntry Clear Enabled -Hash MD5
        }
    }
    Context 'KeyExchangeAlgorithms' {
        It 'DH is disabled' {
            Assert-SchannelRegistryEntry Clear Enabled -KeyExchangeAlgorithm DH
        }
    }
}
