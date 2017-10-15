Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

Describe ScriptBlockInvoker {
    Context construction {
        It 'empty scriptblock' {
            [ScriptBlockInvoker]::new({})
        }
    }
    Context invoke {
        It 'empty scriptblock' {
            [ScriptBlockInvoker]::new({}).Invoke()
        }
    }
    Context 'return value' {
        It 'empty scriptblock' {
            $sbi = [ScriptBlockInvoker]::new({})
            $sbi.Invoke()

            $r = $sbi.ReturnValue

            $r | Should -BeNullOrEmpty
        }
        It 'one string' {
            $sbi = [ScriptBlockInvoker]::new({'string'})
            $sbi.Invoke()

            $r = $sbi.ReturnValue

            $r | Should -Be 'string'
        }
        It 'multiple strings' {
            $sbi = [ScriptBlockInvoker]::new({'one','two'})
            $sbi.Invoke()

            $r = $sbi.ReturnValue
            
            $r | Should -Be 'one','two'
        }
    }
    Context 'variables' {
        It 'ordinary' {
            $a = 'variable a'
            $sbi = [ScriptBlockInvoker]::new(
                {$a},
                $null,
                (Get-Variable a),
                $null
            )
            $sbi.Invoke()

            $r = $sbi.ReturnValue

            $r | Should -Be 'variable a'
        }
        It '$_' {
            $_ = 'dollar bar'
            $sbi = [ScriptBlockInvoker]::new(
                {$_},
                $null,
                (Get-Variable _),
                $null
            )
            $sbi.Invoke()

            $r = $sbi.ReturnValue

            $r | Should -Be 'dollar bar'
        }
    }
    Context 'functions' {
        function f { 'invoked f' }
        $functions = [System.Collections.Generic.Dictionary[string,ScriptBlock]]::new()
        $functions.Add('f',(get-item function:f).ScriptBlock)
        It 'invokes' {
            $sbi = [ScriptBlockInvoker]::new(
                {f},
                $functions,
                $null,
                $null
            )
            $sbi.Invoke()

            $r = $sbi.ReturnValue

            $r | Should -Be 'invoked f'
        }
    }
    Context 'args' {
        It 'one argument' {
            $sbi = [ScriptBlockInvoker]::new(
                {$args},
                $null,
                $null,
                'one'
            )
            $sbi.Invoke()

            $r = $sbi.ReturnValue

            $r | Should -Be 'one'
        }
        It 'two arguments' {
            $sbi = [ScriptBlockInvoker]::new(
                {$args},
                $null,
                $null,
                ('two','one')
            )
            $sbi.Invoke()

            $r = $sbi.ReturnValue

            $r | Should -Be 'two','one'            
        }
    }
    Context 'error stream' {
        $sbi = [ScriptBlockInvoker]::new({Write-Error 'some error';'completed'})
        It 'current thread' {
            $sbi.Invoke()
            $sbi.ReturnValue | Should -Be 'completed'
        }
        It 'another thread' {
            #  this will cause the thread to block
            #$t = [System.Threading.Thread]::new($sbi.InvokeThreadStart)
            #$t.Start()
            #$t.Join()
            #
            #$sbi.ReturnValue | Should -Be 'completed'
        }
    }
    Context 'invoke on another thread' {
        It 'invokes' {
            $sbi = [ScriptBlockInvoker]::new({})
            $t = [System.Threading.Thread]::new($sbi.InvokeThreadStart)

            $t.Start()
            $t.Join()
        }
        It 'returns' {
            $sbi = [ScriptBlockInvoker]::new({'value'})
            $t = [System.Threading.Thread]::new($sbi.InvokeThreadStart)

            $t.Start()
            $t.Join()

            $sbi.ReturnValue | Should -be 'value'
        }
        It 'has a different thread ID' {
            $id = [System.Threading.Thread]::CurrentThread.ManagedThreadId
            $sbi = [ScriptBlockInvoker]::new(
                { [System.Threading.Thread]::CurrentThread.ManagedThreadId }
            )
            $t = [System.Threading.Thread]::new($sbi.InvokeThreadStart)

            $t.Start()
            $t.Join()

            $sbi.ReturnValue | Should -not -BeNullOrEmpty
            $sbi.ReturnValue | Should -not -Be $id
        }
        It 'has the same runspace ID' {
            $id = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.Id
            $sbi = [ScriptBlockInvoker]::new(
                { [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.Id }
            )
            $t = [System.Threading.Thread]::new($sbi.InvokeThreadStart)

            $t.Start()
            $t.Join()

            $sbi.ReturnValue | Should -Be $id
        }
        It 'has the same runspace InstanceId' {
            $id = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InstanceId
            $sbi = [ScriptBlockInvoker]::new(
                { [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InstanceId }
            )
            $t = [System.Threading.Thread]::new($sbi.InvokeThreadStart)

            $t.Start()
            $t.Join()

            $sbi.ReturnValue | Should -Be $id
        }
    }
}