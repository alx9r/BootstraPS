Import-Module "$PSScriptRoot\Bootstraps.psm1" -Force

Describe Afterward {
    class d : System.IDisposable {
        $Disposed = $false
        $Invoked = $false
        $CleanedUp = $false
        $Closed = $false
        Dispose() { $this.Disposed = $true }
        CleanUp() { $this.CleanedUp = $true }
        Close()   { $this.Closed = $true }
        Invoke() {
            if ( $this.Disposed )
            {
                throw 'already disposed'
            }
            if ( $this.CleanedUp )
            {
                throw 'already cleaned up'
            }
            if ( $this.Closed )
            {
                throw 'already closed'
            }
            $this.Invoked = $true
        }
    }
    function throws {
        param([Parameter(ValueFromPipeline)]$i)
        process{ throw 'something' }
    }
    function invokes {
        param([Parameter(ValueFromPipeline)]$i)
        process{ $i.Invoke() }
    }
    function close {
        param([Parameter(ValueFromPipeline)]$i)
        process{ $i.Close() }
    }
    Context 'dispose' {
        It '<n>' -TestCases @(
            @{
                n = 'disposes after output to Out-Null'
                sb = { $d | Afterward -Dispose | Out-Null }
            }
            @{
                n = 'disposes after assigned to $null'
                sb = {$null = $d | Afterward -Dispose }
            }
            @{
                n = 'disposes after output to thrower'
                sb = { 
                    try
                    {
                        $d | Afterward -Dispose | throws
                    }
                    catch {}
                }
            }
            @{
                n = 'disposes after output to invoker'
                sb = { $d | Afterward -Dispose | invokes }
            }
        ) {
            param($sb)
            $d = [d]::new()
            & $sb
            $d.Disposed | Should -Be $true
        }
    }
    Context 'scriptblock' {
        It '<n>' -TestCases @(
            @{
                n = 'invokes scriptblock after output to Out-Null'
                sb = { $d | Afterward { $_.CleanUp() } }
            }
            @{
                n = 'invokes scriptblock after assigned to $null'
                sb = { $null = $d | Afterward { $_.CleanUp() } }
            }
            @{
                n = 'invokes scriptblock after output to thrower'
                sb = { 
                    try
                    {
                        $d | Afterward { $_.CleanUp() } | throws
                    }
                    catch {}
                }
            }
            @{
                n = 'invokes scriptblock after output to invoker'
                sb = { $d | Afterward { $_.CleanUp() } | invokes }
            }

        ) {
            param($sb)
            $d = [d]::new()
            & $sb
            $d.CleanedUp | Should -Be $true
        }
        It 'doesn''t unroll array' {
            ,@(1,2) | Afterward { $r = $_ }
            $r | Should -Be 1,2
        }
    }
}