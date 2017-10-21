Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

InModuleScope Bootstraps {
Describe enumerations {
    It 'use' {
        [BootstraPS.Schannel.Ciphers]::AES_128_128
    }
    It 'folder name attribute' {
        [BootstraPS.Schannel.Ciphers].GetMember('AES_128_128').CustomAttributes | 
            % {$_.ConstructorArguments.Value} |
            Should -Be 'AES 128/128'
    }
}

Describe Get-SchannelRegKeyName {
    It 'returns' {
        $r = [BootstraPS.Schannel.Ciphers]::AES_128_128 | Get-SchannelRegKeyName
        $r.Count | Should -be 1
        $r | Should -BeOfType ([string])
        $r | Should -Be 'AES 128/128'
    }
}
Describe Get-SchannelRegKeyPath {
    It 'returns' {
        $r = Get-SchannelRegKeyPath -Cipher AES_128_128
        $r.Count | Should -be 1
        $r | Should -BeOfType ([string])
        $r | Should -be 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\AES 128/128'
    }
    It 'returns (Protocol)' {
        $r = Get-SchannelRegKeyPath -Protocol SSL_2_0 -Role Client
        $r | Should -be 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client'
    }
}
}
