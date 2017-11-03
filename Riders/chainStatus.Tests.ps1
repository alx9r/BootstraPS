Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

Describe 'ChainStatus after update' {
    It 'is null after success' {
        $cert = Import-Clixml "$PSScriptRoot\..\Resources\certificates\sha256.xml"
        $chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
        $chain.Build($cert) | Should -Be $true
        $chain.ChainStatus | Should -BeNullOrEmpty
    }
    It 'is not null after failure' {
        $cert = Import-Clixml "$PSScriptRoot\..\Resources\certificates\self-signed.xml"
        $chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
        $chain.Build($cert) | Should -Be $false
        $chain.ChainStatus | Should -not -BeNullOrEmpty
    }
}