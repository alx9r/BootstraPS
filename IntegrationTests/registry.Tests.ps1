Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

InModuleScope Bootstraps {
Describe 'x-RegistryProperty' {
    $guid = [guid]::NewGuid().Guid
    $testPath = "HKCU:\Test\$guid"
    It 'setup' {
        New-Item $testPath
        New-ItemProperty $testPath 'SomeProperty' -Value 1 -PropertyType DWORD
    }
    Context 'Get-' {
        Context 'existent' {
            Context 'returns' {
                $r = $testPath | Get-RegistryProperty SomeProperty
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
                        $r.PropertyName | Should -Be 'SomeProperty'
                    }
                    It 'Value' {
                        $r.Value | Should -Be 1
                    }
                    It 'Kind' {
                        $r.Kind | Should -be ([Microsoft.Win32.RegistryValueKind]::DWord)
                    }
                }
            }
        }
        Context 'non-existent' {
            It 'returns nothing' {
                $r = $testPath | Get-RegistryProperty bogus
                $r | Should -BeNullOrEmpty
            }
        }
    }
    Context 'Test-' {
        It 'true' {
            $r = $testPath | Test-RegistryProperty SomeProperty 1
            $r | Should -Be $true
        }
        It 'false' {
            $r = $testPath | Test-RegistryProperty bogus 1
            $r | Should -Be $false
        }
    }
    Context 'Set-' {
        It 'returns nothing' {
            $r = $testPath | Set-RegistryProperty SomeOtherProperty -Value 1 -Kind DWORD
            $r | Should -BeNullOrEmpty
        }
        It 'test' {
            $r = $testPath | Get-RegistryProperty SomeOtherProperty
            $r.Value | Should -Be 1
            $r.Kind | Should -be ([Microsoft.Win32.RegistryValueKind]::DWord)
        }
    }
    It 'teardown' {
        Remove-Item $testPath
    }
}
}