Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

InModuleScope Bootstraps {

Describe Out-ScriptSpan {
    $sb1 = {a;b;c;}
    $sb2 = {
        a
        b
        c
    }
    $sb3 = {a}
    It '<n>' -TestCases @(
        @{
            n = 'end of single character statement'
            sb = $sb3
            from = $sb3.Ast.EndBlock.Statements[0].Extent
            e = '}'
        }
        @{
            n = 'from only'
            sb = $sb1
            from = $sb1.Ast.EndBlock.Statements[0].Extent
            e = ';b;c;}'
        }
        @{
            n = 'to only'
            sb = $sb1
            to = $sb1.Ast.EndBlock.Statements[2].Extent
            e = '{a;b;'
        }
        @{
            n = 'from to'
            sb = $sb1
            from = $sb1.Ast.EndBlock.Statements[0].Extent
            to =   $sb1.Ast.EndBlock.Statements[2].Extent
            e = ';b;'
        }
        @{
            n= 'multiline from only'
            sb = $sb2
            from = $sb2.Ast.EndBlock.Statements[0].Extent
            e = @'

        b
        c
    }
'@
        }
        @{
            n= 'multiline to only'
            sb = $sb2
            to = $sb2.Ast.EndBlock.Statements[2].Extent
            e = @'
{
        a
        b
        
'@
        }
        @{
            n = 'multiline from to'
            sb = $sb2
            from = $sb2.Ast.EndBlock.Statements[0].Extent
            to =   $sb2.Ast.EndBlock.Statements[2].Extent
            e = @'

        b
        
'@
        }
    ) {
        param($sb,$from,$to,$e)
        $r = $sb | Out-ScriptSpan $from $to
        $r | Should -be $e
    }
}

Describe ConvertFrom-Scriptblock {
    It '<n>' -TestCases @(
        @{n='n';sb={};e=''}
    ) {
        param($n,$sb)

    }
}

Describe ConvertTo-ScriptWithoutUsing {
    It '<n>' -TestCases @(
        @{
            n = 'empty'
            i = {}
            o = {}
        }
        @{
            n = 'single'
            i = {$using:a}
            o = {$a}
        }
        @{
            n = 'multiple'
            i = {$using:a;$using:b;$using:c}
            o = {$a;$b;$c}
        }
        @{
            n = 'multiline'
            i = {
                $using:a
                $using:b
            }
            o = {
                $a
                $b
            }
        }
        @{
            n = 'string interpolation'
            i = {"$using:a"}
            o = {"$a"}
        }
        @{
            n = '[scriptblock]::Create('''')'
            i = [scriptblock]::Create('')
            o = {}
        }
        @{
            n ='[scriptblock]::Create({123})'
            i = [scriptblock]::Create({123})
            o = {123}
        }
        @{
            n ='[scriptblock]::Create({$using:a})'
            i = [scriptblock]::Create({$using:a})
            o = {$a}
        }
    ) {
        param($i,$o)
        $r = $i | ConvertTo-ScriptWithoutUsing
         $r | Should -BeOfType ([scriptblock])
        &$r | Should -not -BeOfType ([scriptblock])
        $r.Ast.Extent.Text | Should -be ($o.Ast.Extent.Text)
    }
}
}