Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

InModuleScope Bootstraps {

Describe FixPSBoundParameters {
    Context BeginFixPSBoundParameters {
        Context 'returns' {
            function f {param($a) $PSBoundParameters }
            $r = f -a 1 | BeginFixPSBoundParameters
            It 'count' {
                $r.Count | Should -be 1
            }
            It 'type' {
                $r | Should -beOfType ([Bootstraps.Metaprogramming.ParameterHashtable])
            }
            It 'property Hashtable' {
                $r.Hashtable.a | Should -Be 1
            }
        }
    }
    Context ProcessFixPSBoundParameters {
        Context 'non-empty' {
            function f {param($a,$b) $PSBoundParameters}
            $psbp = (f -a 1 -b 2)
            $splat = @{
                ThisPSBoundParameters = $psbp
                CommandLineParameters = @{a=1}
            }
            $r = ProcessFixPSBoundParameters @splat
            Context 'removes' {
                It 'param not mentioned in CommandLineParameters' {
                    $psbp.b | Should -BeNullOrEmpty
                }
            }
            Context 'returns' {
                It 'all input params' {
                    $r.a | Should -Be 1
                    $r.b | Should -Be 2
                }
            }
        }
        Context 'empty input' {
            It 'no param()' {
                function f {$PSBoundParameters}
                ([Bootstraps.Metaprogramming.ParameterHashtable]@{}) | ProcessFixPSBoundParameters (f)
            }
            It 'no arguments' {
                function f {param($a) $PSBoundParameters}
                (f).GetType().FullName | Should -be 'System.Management.Automation.PSBoundParametersDictionary'
            }
        }
    }
    Context 'in use' {
        class a {}
        class b {}
    
        function f {
            param
            (
                [Parameter(ParameterSetName='a',ValueFromPipeline)][a]$A,
                [Parameter(ParameterSetName='b',ValueFromPipeline)][b]$B,
                $C
            )
            begin
            {
                $CommandLineParameters = $PSBoundParameters | BeginFixPSBoundParameters
            }
            process
            {
                $BoundParameters = $CommandLineParameters | ProcessFixPSBoundParameters $PSBoundParameters
                [hashtable]$BoundParameters
            }
        }            
        $r = [a]::new(),[b]::new(),[a]::new() | f -C 1
        It 'first record' {
            $r[0].Keys | Should -be 'A','C'
        }
        It 'second record' {
            $r[1].Keys | Should -be 'B','C'
        }
        It 'third record' {
            $r[0].Keys | Should -be 'A','C'
        }
    }
}
}