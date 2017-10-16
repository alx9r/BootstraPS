Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

InModuleScope Bootstraps {

Describe Get-ParameterMetaData {
    function f { param($x,$y) }
    It 'returns one parameter info object for existent parameter' {
        $r = Get-Command f | Get-ParameterMetaData 'x'
        $r.Count | Should be 1
        $r.Name | Should be 'x'
        $r | Should beOfType ([System.Management.Automation.ParameterMetadata])
    }
    It 'returns nothing for non-existent parameter' {
        $r = Get-Command f | Get-ParameterMetaData 'z'
        $r | Should beNullOrEmpty
    }
    It 'returns all parameters for omitted parameter name' {
        $r = Get-Command f | Get-ParameterMetaData
        $r.Count | Should be 2
    }
    It 'returns nothing for no input parameters' {
        function f {}
        $r = Get-Command f | Get-ParameterMetaData
        $r | Should beNullOrEmpty
    }
    It 'returns nothing for corrupted input parameters' {
        function f {param([BadAttribute()]$x)}
        $r = Get-Command f | Get-ParameterMetaData
        $r | Should beNullOrEmpty
    }
}
}
