Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

InModuleScope Bootstraps {
Describe Get-RegKeyPropertyInfo {
    $guid = [guid]::NewGuid().Guid
    $testPath = "HKCU:\Test\$guid"
    It 'setup' {
        New-Item $testPath
        New-ItemProperty $testPath 'SomeProperty' -Value 1 -PropertyType DWORD
    }
    Context 'returns' {
        $r = $testPath | Get-RegKeyPropertyInfo SomeProperty
        It 'count' {
            $r.Count | Should -Be 1
        }
        It 'type' {
            $r | Should -BeOfType ([RegKeyPropertyInfo])
        }
        Context 'property' {
            It 'Path' {
                $r.Path | Should -Be $testPath
            }
            It 'PropertyName' {
                $r.PropertyName | Should -be 'SomeProperty'
            }
            It 'Value' {
                $r.Value | Should -be 1
            }
            It 'Kind' {
                $r.Kind | Should -be ([Microsoft.Win32.RegistryValueKind]::DWord)
            }
        }
    }
    It 'teardown' {
        Remove-Item $testPath
    }
}
}