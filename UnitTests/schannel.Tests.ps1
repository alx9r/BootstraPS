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

Describe Get-SchannelKeyName {
    It 'returns' {
        $r = [BootstraPS.Schannel.Ciphers]::AES_128_128 | Get-SchannelKeyName
        $r.Count | Should -be 1
        $r | Should -BeOfType ([string])
        $r | Should -Be 'AES 128/128'
    }
}
Describe Get-SchannelKeyPath {
    It 'returns' {
        $r = Get-SchannelKeyPath -Cipher AES_128_128
        $r.Count | Should -be 1
        $r | Should -BeOfType ([string])
        $r | Should -be 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\AES 128/128'
    }
    It 'returns (Protocol)' {
        $r = Get-SchannelKeyPath -Protocol SSL_2_0 -Role Client
        $r | Should -be 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client'
    }
}
Describe Test-SchannelRegistryEntry {
    $splat = @{ Cipher = [BootstraPS.Schannel.Ciphers]::AES_128_128 }
    Context 'non-existent' {
        Mock Get-SchannelRegistryEntry { 
            [BootstraPS.Registry.PropertyAbsentInfo]::new(
                'path',
                'propertyName'
            )
        }
        It 'returns <o> for <s>' -TestCases @(
            @{ s=[BootstraPS.Schannel.PropertyState]::Absent;o=$true  }
            @{ s=[BootstraPS.Schannel.PropertyState]::Clear; o=$false }
            @{ s=[BootstraPS.Schannel.PropertyState]::Set;   o=$false }
        ) {
            param($s,$o)
            $r = Test-SchannelRegistryEntry $s Enabled @splat
            $r | Should -Be $o
        }
    }
    Context 'kind is string' {
        Mock Get-SchannelRegistryEntry {
            [BootstraPS.Registry.PropertyPresentInfo]::new(
                'path',
                'propertyName',
                'string',
                [Microsoft.Win32.RegistryValueKind]::String
            )
        }
        Mock Write-Warning -Verifiable
        It 'returns <o> for <s>' -TestCases @(
            @{ s=[BootstraPS.Schannel.PropertyState]::Absent;o=$false }
            @{ s=[BootstraPS.Schannel.PropertyState]::Clear; o=$false }
            @{ s=[BootstraPS.Schannel.PropertyState]::Set;   o=$false }
        ) {
            param($s,$o)
            $r = Test-SchannelRegistryEntry $s Enabled @splat
            $r | Should -Be $o
        }
        It 'outputs warning' {
            Assert-MockCalled Write-Warning 3 {
                $Message -match 'invalid kind'
            }
        }
    }
    Context 'value is bogus' {
        Mock Get-SchannelRegistryEntry {
            [BootstraPS.Registry.PropertyPresentInfo]::new(
                'path',
                'propertyName',
                0x12345678,
                [Microsoft.Win32.RegistryValueKind]::DWord
            )
        }
        Mock Write-Warning -Verifiable
        It 'returns <o> for <s>' -TestCases @(
            @{ s=[BootstraPS.Schannel.PropertyState]::Absent;o=$false }
            @{ s=[BootstraPS.Schannel.PropertyState]::Clear; o=$false }
            @{ s=[BootstraPS.Schannel.PropertyState]::Set;   o=$false }
        ) {
            param($s,$o)
            $r = Test-SchannelRegistryEntry $s Enabled @splat
            $r | Should -Be $o
        }
        It 'outputs warning' {
            Assert-MockCalled Write-Warning 3 {
                $Message -match 'invalid value'
            }
        }            
    }
    Context '[EnabledType]::Enabled' {
        Context '[EnabledValues]::Clear' {
            Mock Get-SchannelRegistryEntry {
                [BootstraPS.Registry.PropertyPresentInfo]::new(
                    'path',
                    'propertyname',
                    [BootstraPS.Schannel.EnabledValues]::Clear,
                    [Microsoft.Win32.RegistryValueKind]::DWord
                )
            }
            It 'returns <o> for <s>' -TestCases @(
                @{ s=[BootstraPS.Schannel.PropertyState]::Absent;o=$false }
                @{ s=[BootstraPS.Schannel.PropertyState]::Clear; o=$true  }
                @{ s=[BootstraPS.Schannel.PropertyState]::Set;   o=$false }
            ) {
                param($s,$o)
                $r = Test-SchannelRegistryEntry $s Enabled @splat
                $r | Should -Be $o
            }
        }
        Context '[EnabledValues]::Set' {
            Mock Get-SchannelRegistryEntry {
                [BootstraPS.Registry.PropertyPresentInfo]::new(
                    'path',
                    'propertyname',
                    [BootstraPS.Schannel.EnabledValues]::Set,
                    [Microsoft.Win32.RegistryValueKind]::DWord
                )
            }
            It 'returns <o> for <s>' -TestCases @(
                @{ s=[BootstraPS.Schannel.PropertyState]::Absent;o=$false }
                @{ s=[BootstraPS.Schannel.PropertyState]::Clear; o=$false }
                @{ s=[BootstraPS.Schannel.PropertyState]::Set;   o=$true  }
            ) {
                param($s,$o)
                $r = Test-SchannelRegistryEntry $s Enabled @splat
                $r | Should -Be $o
            }
        }
    }
    Context '[EnableType]::DisabledByDefault' {
        Context '[DisabledByDefaultValues]::Clear' {
            Mock Get-SchannelRegistryEntry {
                [BootstraPS.Registry.PropertyPresentInfo]::new(
                    'path',
                    'propertyname',
                    [BootstraPS.Schannel.DisabledByDefaultValues]::Clear,
                    [Microsoft.Win32.RegistryValueKind]::DWord
                )
            }
            It 'returns <o> for <s>' -TestCases @(
                @{ s=[BootstraPS.Schannel.PropertyState]::Absent;o=$false }
                @{ s=[BootstraPS.Schannel.PropertyState]::Clear; o=$true  }
                @{ s=[BootstraPS.Schannel.PropertyState]::Set;   o=$false }
            ) {
                param($s,$o)
                $r = Test-SchannelRegistryEntry $s DisabledByDefault @splat
                $r | Should -Be $o
            }
        }
        Context '[DisabledByDefaultValues]::Set' {
            Mock Get-SchannelRegistryEntry {
                [BootstraPS.Registry.PropertyPresentInfo]::new(
                    'path',
                    'propertyname',
                    [BootstraPS.Schannel.DisabledByDefaultValues]::Set,
                    [Microsoft.Win32.RegistryValueKind]::DWord
                )
            }
            It 'returns <o> for <s>' -TestCases @(
                @{ s=[BootstraPS.Schannel.PropertyState]::Absent;o=$false }
                @{ s=[BootstraPS.Schannel.PropertyState]::Clear; o=$false }
                @{ s=[BootstraPS.Schannel.PropertyState]::Set;   o=$true  }
            ) {
                param($s,$o)
                $r = Test-SchannelRegistryEntry $s DisabledByDefault @splat
                $r | Should -Be $o
            }
        }
    }
}
}
