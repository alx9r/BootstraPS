Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

Describe ScriptBlockInvoker {
    Context construction {
        It 'empty scriptblock' {
            [BootstraPS.Concurrency.ScriptBlockInvoker]::new({})
        }
    }
    foreach ( $p in @(
        @{
            n='single thread'
            invoker={$_.Invoke()}
        }
        @{
            n='another thread'
            invoker= {
                $t = [System.Threading.Thread]::new($_.InvokeThreadStart)
                $t.Start()
                $t.Join()
            }
        }
    ))
    {
    Context $p.n {
    Context invoke {
        It 'empty scriptblock' {
            [BootstraPS.Concurrency.ScriptBlockInvoker]::new({}) | 
                % $p.invoker
        }
        It 'foreach' {
            [BootstraPS.Concurrency.ScriptBlockInvoker]::new({1 | foreach 1}) |
                % $p.invoker
        }
    }
    Context 'return value' {
        It 'empty scriptblock' {
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new({})
            $sbi | % $p.invoker

            $r = $sbi.ReturnValue

            $r | Should -BeNullOrEmpty
        }
        It 'one string' {
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new({'string'})
            $sbi | % $p.invoker

            $r = $sbi.ReturnValue

            $r | Should -Be 'string'
        }
        It 'multiple strings' {
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new({'one','two'})
            $sbi | % $p.invoker

            $r = $sbi.ReturnValue
            
            $r | Should -Be 'one','two'
        }
    }
    Context 'variables' {
        It 'read' {
            $a = 'variable a'
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new(
                {$a},
                $null,
                (Get-Variable a)
            )
            $sbi | % $p.invoker

            $r = $sbi.ReturnValue

            $r | Should -Be 'variable a'
        }
        It 'write' {
            $a = 'original value'
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new(
                {$a = 'new value'},
                $null,
                (Get-Variable a)
            )
            $sbi | % $p.invoker

            $a | Should -Be 'original value'
        }
        It 'write member' {
            $h = @{a='original value'}
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new(
                {$h.a = 'new value'},
                $null,
                (Get-Variable h)
            )
            $sbi | % $p.invoker

            $h.a | Should -be 'new value'
        }
        It '$_' {
            $_ = 'dollar bar'
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new(
                {$_},
                $null,
                (Get-Variable _),
                $null
            )
            $sbi | % $p.invoker

            $r = $sbi.ReturnValue

            $r | Should -Be 'dollar bar'
        }
    }
    Context 'functions' {
        function f { 'invoked f' }
        It 'invokes' {
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new(
                {f},
                (Get-Command f),
                $null,
                $null
            )

            $sbi | % $p.invoker

            $r = $sbi.ReturnValue

            $r | Should -Be 'invoked f'
        }
    }
    Context 'args' {
        It 'one argument' {
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new(
                {$args},
                $null,
                $null,
                'one'
            )
            $sbi | % $p.invoker

            $r = $sbi.ReturnValue

            $r | Should -Be 'one'
        }
        It 'two arguments' {
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new(
                {$args},
                $null,
                $null,
                ('two','one')
            )
            $sbi | % $p.invoker

            $r = $sbi.ReturnValue

            $r | Should -Be 'two','one'            
        }
    }
    Context 'positional parameters' {
        It 'one parameter' {
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new(
                {param($a)$a},
                $null,
                $null,
                'one'
            )

            $sbi | % $p.invoker

            $r = $sbi.ReturnValue

            $r | Should be 'one'
        }
        It 'two parameters' {
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new(
                {param($a,$b)$a,$b},
                $null,
                $null,
                ('one','two')
            )

            $sbi | % $p.invoker

            $r = $sbi.ReturnValue

            $r | Should be 'one','two'
        }
    }
    Context 'named parameters' {
        It 'one parameter' {
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new(
                {param($a)$a},
                $null,
                $null,
                $null,
                @{a='one'}
            )

            $sbi | % $p.invoker

            $r = $sbi.ReturnValue

            $r | Should be 'one'
        }
        It 'two parameters' {
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new(
                {param($a,$b)$a,$b},
                $null,
                $null,
                $null,
                @{b='two';a='one'}
            )

            $sbi | % $p.invoker

            $r = $sbi.ReturnValue

            $r | Should be 'one','two'
        }
    }
    Context 'error stream' {
        $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new({Write-Error 'some error';'completed'})
        It 'completes' {
            $sbi | % $p.invoker
            $sbi.ReturnValue | Should -Be 'completed'
        }
    }
    }}
    Context 'invoke on another thread' {
        It 'invokes' {
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new({})
            $t = [System.Threading.Thread]::new($sbi.InvokeThreadStart)

            $t.Start()
            $t.Join()
        }
        It 'returns' {
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new({'value'})
            $t = [System.Threading.Thread]::new($sbi.InvokeThreadStart)

            $t.Start()
            $t.Join()

            $sbi.ReturnValue | Should -be 'value'
        }
        function fibonacci
        {
            param($n)
            if ( $n -le 1 )
            {
                return 1
            }
            return (fibonacci ($n-1)) + (fibonacci ($n-2))
        }
        It 'scriptblock x10 : <sb>' -TestCases @(
            @{sb={}}
            @{sb={'value'}}
            @{sb={ 1 | ForEach-Object 1 }}
            @{sb={ fibonacci 15 } }
        ) {
            param($sb)
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new($sb,(Get-Command fibonacci))

            $t = 1..10 | % { [System.Threading.Thread]::new($sbi.InvokeThreadStart) }

            $t | % {$_.Start()}
            $success = $t | % { $_.Join(10000) }

            $success | % {$_ | Should -Be $true }
        }
        It 'events marshalled to main thread while background thread executing' {
            # per https://github.com/PowerShell/PowerShell/pull/4970#discussion_r143785852
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new({fibonacci 18},(Get-Command fibonacci))

            Unregister-Event *
            $timers = 1..100 |
                % {
                    $id = "event$_"
                    $tm = [System.Timers.Timer]::new($_)
                    $tm.AutoReset = $false
                    Register-ObjectEvent -SourceIdentifier $id -InputObject $tm -EventName elapsed -Action { Write-Host "$($Event.SourceIdentifier)," -NoNewline } | Out-Null
                    $tm.Enabled = $true
                    $tm
                }

            $th = [System.Threading.Thread]::new($sbi.InvokeThreadStart)

            $th.Start()
            fibonacci 18
            $success = $th.Join(10000)
            $success | Should -Be $true
        }
        It 'update same object in callback and event handler' {
            # per https://github.com/PowerShell/PowerShell/pull/4970#issuecomment-340191741

            $h = @{a = 'original value'}
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new(
                {
                    $h.a = 'thread value'
                    fibonacci 18
                    $h.a = 'thread value'
                },
                (Get-Command fibonacci),
                (Get-Variable h)
            )

            Unregister-Event *
            $timers = 1..100 |
                % {
                    $id = "event$_"
                    $tm = [System.Timers.Timer]::new($_)
                    $tm.AutoReset = $false
                    Register-ObjectEvent -SourceIdentifier $id -InputObject $tm -MessageData $h -EventName elapsed -Action { 
                        Write-Host "$($Event.SourceIdentifier)," -NoNewline
                        $h.a = 'event handler value'
                    } | Out-Null
                    $tm.Enabled = $true
                    $tm
                }
            $th = [System.Threading.Thread]::new($sbi.InvokeThreadStart)

            $th.Start()
            fibonacci 18
            $success = $th.Join(10000)
            $success | Should -Be $true            
        }
        It 'has a different thread ID' {
            $id = [System.Threading.Thread]::CurrentThread.ManagedThreadId
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new(
                { [System.Threading.Thread]::CurrentThread.ManagedThreadId }
            )
            $t = [System.Threading.Thread]::new($sbi.InvokeThreadStart)

            $t.Start()
            $t.Join()

            $sbi.ReturnValue | Should -not -BeNullOrEmpty
            $sbi.ReturnValue | Should -not -Be $id
        }
        It 'has a different runspace ID' {
            $id = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.Id
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new(
                { [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.Id }
            )
            $t = [System.Threading.Thread]::new($sbi.InvokeThreadStart)

            $t.Start()
            $t.Join()
            
            $sbi.ReturnValue | Should -BeOfType ([int])
            $sbi.ReturnValue | Should -Not -Be $id
        }
        It 'has the same runspace InstanceId' {
            $id = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InstanceId
            $sbi = [BootstraPS.Concurrency.ScriptBlockInvoker]::new(
                { [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InstanceId }
            )
            $t = [System.Threading.Thread]::new($sbi.InvokeThreadStart)

            $t.Start()
            $t.Join()

            $sbi.ReturnValue | Should -BeOfType ([guid])
            $sbi.ReturnValue | Should -Not -Be $id
        }
    }
}