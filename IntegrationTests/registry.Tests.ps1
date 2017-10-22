Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

InModuleScope Bootstraps {
Describe New-RegistryKey {
    $guid = [guid]::NewGuid().Guid
    $testPath = "HKCU:\Test\$guid"
    It 'setup' {
        New-Item $testPath -Force -ErrorAction SilentlyContinue
        New-ItemProperty $testPath 'SomeProperty' -Value 1 -PropertyType DWORD
    }
    Context 'create' {
        $r = $testPath | New-RegistryKey
        Context 'return' {
            It 'count' {
                $r.Count | Should -Be 1
            }
            It 'type' {
                $r | Should -BeOfType ([BootstraPS.Registry.RegPropPresentInfo])
            }
            Context 'property' {
                It 'Path' {
                    $r.Path | Should -Be $testPath
                }
                It 'PropertyName' {
                    $r.Propert
                }
            }
        }
    }
    Context 'already exists' {}
    Context 'recursive' {}
    Context 'forward slash' {}
    It 'teardown' {
        Remove-Item $testPath
    }       
}
Describe 'x-RegistryProperty' {
    $guid = [guid]::NewGuid().Guid
    $testPath = "HKCU:\Test\$guid"
    It 'setup' {
        New-Item $testPath -Force -ErrorAction SilentlyContinue
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
                    $r | Should -BeOfType ([BootstraPS.Registry.RegPropPresentInfo])
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
        Context 'create' {
            It 'returns nothing' {
                $r = $testPath | Set-RegistryProperty SomeOtherProperty -Value 1 -Kind DWord
                $r | Should -BeNullOrEmpty
            }
            It 'test' {
                $r = $testPath | Get-RegistryProperty SomeOtherProperty
                $r.Value | Should -Be 1
                $r.Kind | Should -be ([Microsoft.Win32.RegistryValueKind]::DWord)
            }
        }
        Context 'remove' {
            $testPath | Set-RegistryProperty WillBeRemoved -Value 1 -Kind DWord
            It 'returns nothing' {
                $r = $testPath | Set-RegistryProperty WillBeRemoved -Absent
                $r | Should -BeNullOrEmpty
            }
            It 'test' {
                $r = $testPath | Get-RegistryProperty WillBeRemoved
                $r | Should -BeNullOrEmpty
            }
        }
    }
    It 'teardown' {
        Remove-Item $testPath
    }
}
Describe Get-RegistryPropertyInfo {
    $guid = [guid]::NewGuid().Guid
    $testPath = "HKCU:\Test\$guid"
    It 'setup' {
        New-Item $testPath
        New-ItemProperty $testPath 'SomeProperty' -Value 1 -PropertyType DWORD
    }
    Context 'restore' {
        Context 'existent' {
            Context 'restore' {
                $i = $testPath | Get-RegistryPropertyInfo SomeProperty
                Remove-ItemProperty $testPath SomeProperty
                It 're-create' {
                    $i | Set-RegistryProperty
                }
                It 'test' {
                    $r = $testPath | Get-RegistryProperty SomeProperty
                    $r.Value | Should -Be 1
                    $r.Kind | Should -Be DWord
                }
            }
            Context 'cure value' {
                $i = $testPath | Get-RegistryPropertyInfo SomeProperty
                Remove-ItemProperty $testPath SomeProperty
                $testPath | Set-RegistryProperty SomeProperty 2 -Kind DWord
                It 'cure' {
                    $i | Set-RegistryProperty
                }
                It 'test' {
                    $r = $testPath | Get-RegistryProperty SomeProperty
                    $r.Value | Should -Be 1
                    $r.Kind | Should -Be DWord
                }
            }
            Context 'cure kind' {
                $i = $testPath | Get-RegistryPropertyInfo SomeProperty
                Remove-ItemProperty $testPath SomeProperty
                $testPath | Set-RegistryProperty SomeProperty 'one' -Kind String
                It 'cure' {
                    $i | Set-RegistryProperty
                }
                It 'test' {
                    $r = $testPath | Get-RegistryProperty SomeProperty
                    $r.Value | Should -Be 1
                    $r.Kind | Should -Be DWord                    
                }
            }
        }
        Context 'non-existent' {
            Context 'remove' {
                $i = $testPath | Get-RegistryPropertyInfo WillBeRemoved
                $testPath | Set-RegistryProperty WillBeRemoved 1 -Kind DWord
                It 'remove' {
                    $i | Set-RegistryProperty
                }
                It 'test' {
                    $r = $testPath | Get-RegistryProperty WillBeRemoved
                    $r | Should -BeNullOrEmpty
                }
            }
        }
    }
    It 'teardown' {
        Remove-Item $testPath
    }
}
}