Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

InModuleScope Bootstraps {
Describe Get-RegistryKey {
    $guid = [guid]::NewGuid().Guid
    $testPath = "HKCU:\Test\$guid"
    It 'setup' {
        New-Item $testPath -Force -ErrorAction SilentlyContinue
    }
    Context 'existent' {
        Context 'return' {
            $r = $testPath | Get-RegistryKey
            It 'count' {
                $r.Count | Should -Be 1
            }
            It 'type' {
                $r | Should -BeOfType ([BootstraPS.Registry.RegKeyPresentInfo])
            }
            It 'Path property' {
                $r.Path | Should -be $testPath
            }
        }
    }
    Context 'non-existent' {
        It 'returns nothing' {
            $r = $testPath+'\nonexistent' | Get-RegistryKey
            $r | Should -BeNullOrEmpty
        }
    }
    It 'teardown' {
        Remove-Item $testPath
    } 
}
Describe Set-RegistryKey {
    $guid = [guid]::NewGuid().Guid
    $testPath = "HKCU:\Test\$guid"
    It 'setup' {
        New-Item $testPath -Force -ErrorAction SilentlyContinue
    }
    Context 'create' {
        It 'returns nothing' {
            $r = $testPath | Set-RegistryKey
            $r | Should -BeNullOrEmpty
        }
        It 'test' {
            $r = $testPath | Get-RegistryKey
            $r | Should -Not -BeNullOrEmpty
        }
    }
    Context 'already exists' {
        It 'returns nothing' {
            $r = $testPath | Set-RegistryKey
            $r | Should -BeNullOrEmpty
        }
    }
    Context 'recursive' {
        It 'returns nothing' {
            $r = $testPath+'\a\b' | Set-RegistryKey
            $r | Should -BeNullOrEmpty
        }
        It 'test <p>' -TestCases @(
            @{p=$testPath+'\a'}
            @{p=$testPath+'\a\b'}
        ) {
            param($p)
            $r = $p | Get-RegistryKey
            $r | Should -Not -BeNullOrEmpty
        }
    }
    Context 'forward slash' {
        It 'returns nothing' {
            $r = $testPath+'\c/d' | Set-RegistryKey
            $r | Should -BeNullOrEmpty
        }
        It 'test <p> exists' -TestCases @(
            @{p=$testPath}
            @{p=$testPath+'\c/d'}
        ) {
            param($p)
            $r = $p | Get-RegistryKey
            $r | Should -Not -BeNullOrEmpty
        }
        It 'test <p> does not exist' -TestCases @(
            @{p=$testPath+'\c'}
        ) {
            param($p)
            $r = $p | Get-RegistryKey
            $r | Should -BeNullOrEmpty
        }
    }
    It 'teardown' {
        Remove-Item $testPath -Recurse
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
        Context 'create in non-existent key' {
            It 'returns nothing' {
                $r = $testPath+'\MustBeCreated' | Set-RegistryProperty SomeProperty -Value 1 -Kind DWord
                $r | Should -BeNullOrEmpty
            }
            It 'test' {
                $r = $testPath+'\MustBeCreated' | Get-RegistryProperty SomeProperty
                $r | Should -Not -BeNullOrEmpty
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
        Remove-Item $testPath -Recurse
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