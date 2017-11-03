Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

. "$PSScriptRoot\..\helpers.ps1"

Describe Assert-SignatureAlgorithm {
    It 'throws' {
        $c = Import-Clixml $PSScriptRoot\..\Resources\certificates\sha1-intermediate.xml
        try
        { 
            $c | Assert-SignatureAlgorithm Strict
        }
        catch
        {
            $threw = $true
            $_.Exception | CoalesceExceptionMessage |
                Should -Match 'signature algorithm is sha1RSA'
        }
        $threw | Should -Be $true
    }
}

Describe Assert-X509Compliance {
    It 'returns nothing' {
        $c = Import-Clixml $PSScriptRoot\..\Resources\certificates\sha256.xml
        $r = $c | Assert-X509Compliance Strict
        $r | Should -BeNullOrEmpty
    }
}