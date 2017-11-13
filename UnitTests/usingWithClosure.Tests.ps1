Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

. "$PSScriptRoot\..\helpers.ps1"

InModuleScope Bootstraps {

Describe Get-UsingVariable {
    Context 'return' {
        $r = & ([scriptblock]::Create({
            $a = 1; $b = 2; $c = 3
            {$using:a; $using:c}.GetNewClosure() 
        })) |
            Get-UsingVariable
        It 'count' {
            $r | Measure | % Count | Should -be 2
        }
        It 'type' {
            $r | Should -BeOfType ([psvariable])
        }
        Context 'property' {
            It 'Name' {
                $r.Name | Should -be 'a','c'
            }
            It 'Value' {
                $r.Value | Should -be 1,3
            }
        }
    }
    Context 'no closure, no using statement' {
        $sb = [scriptblock]::Create({})
        It 'returns nothing' {
            $r = $sb | Get-UsingVariable
            $r | Should -BeNullOrEmpty
        }
    }
    Context 'no closure' {
        $sb = [scriptblock]::Create({$using:a})
        It 'scriptblock with no module...' {
            $sb.Module | Should -BeNullOrEmpty
        }
        It '...throws' {
            { $sb | Get-UsingVariable } |
                Should -Throw 'using:a'
        }
    }
    Context 'missing variable' {
        $sb = & ([scriptblock]::Create({{$using:bogus}.GetNewClosure()}))
        It 'throws' {
            { $sb | Get-UsingVariable } |
                Should -Throw '$using:bogus'
        }
    }
}
Describe ConvertFrom-UsingWithClosure {
    Context 'return' {
        Mock ConvertTo-ScriptWithoutUsing { {script_without_using} }
        Mock Get-UsingVariable { $using_variable=1; Get-Variable using_variable }
        $r = [scriptblock]::Create(
            {
                $a = 1
                $b = 2
                $c = 3
                {$using:a;$using:b;$c}.GetNewClosure()
            }
        ) | ConvertFrom-UsingWithClosure
        It 'count' {
            $r | Measure | % Count | Should -be 1
        }
        It 'type' {
            $r | Should -BeOfType ([System.Management.Automation.PSCustomObject])
        }
        Context 'property' {
            It 'VariablesToDefine' {
                $r.VariablesToDefine.Name | 
                    Should -Be 'using_variable'
            }
            It 'ScriptBlock' {
                $r.ScriptBlock | Should -Be 'script_without_using'
            }
        }
    }
    Context 'invokes' {
        Mock ConvertTo-ScriptWithoutUsing -Verifiable
        Mock Get-UsingVariable -Verifiable
        { MyStatement } | ConvertFrom-UsingWithClosure
        It 'invokes' {
            Assert-MockCalled ConvertTo-ScriptWithoutUsing 1 {
                [string]$ScriptBlock -like '*MyStatement*'
            }
            Assert-MockCalled Get-UsingVariable 1 {
                [string]$ScriptBlock -like '*MyStatement*'
            }
        }
    }
    Context 'null' {
        Context 'return' {
            $r = $null | ConvertFrom-UsingWithClosure
            Context 'property' {
                It 'VariablesToDefine' {
                    $r.VariablesToDefine | Should -BeNullOrEmpty
                }
                It 'ScriptBlock' {
                    $r.VariablesToDefine | Should -BeNullOrEmpty
                }
            }
        }
    }
}
}