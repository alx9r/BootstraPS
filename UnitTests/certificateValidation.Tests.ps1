Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

. "$PSScriptRoot\..\helpers.ps1"

Describe 'Certificate Validation' {
    It 'sha1-intermediate' -TestCases @(
        @{n='sha1-intermediate';m='signature algorithm is sha1RSA'}
    ) {
        param($n,$m)
        try
        { 
            Import-Clixml $PSScriptRoot\..\Resources\certificates\$n.xml |
                Assert-SignatureAlgorithm -Strict
        }
        catch
        {
            $threw = $true
            $_.Exception | CoalesceExceptionMessage |
                Should -Match $m
        }
        $threw | Should -Be $true
    }
}