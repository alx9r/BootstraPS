Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

InModuleScope Bootstraps {

Describe Get-ParameterAst {
    function f { param($x,$y) }
    It 'returns parameter abstract syntax tree for existent parameter' {
        $r = Get-Command f | Get-ParameterAst 'x'
        $r.Count | Should be 1
        $r.Name | Should be '$x'
        $r | Should beOfType ([System.Management.Automation.Language.ParameterAst])
    }
    It 'returns nothing for non-existent parameter' {
        $r = Get-Command f | Get-ParameterAst 'z'
        $r | Should beNullOrEmpty
    }
    It 'returns all parameters for omitted parameter name' {
        $r = Get-Command f | Get-ParameterAst
        $r.Count | Should be 2
    }
}
}
