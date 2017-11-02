Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

Describe Assert-X509ChainStatus {
    Context 'success' {
        $s = [System.Security.Cryptography.X509Certificates.X509ChainStatus]@{
            Status = [System.Security.Cryptography.X509Certificates.X509ChainStatusFlags]::NoError
        }
        It 'returns nothing' {
            $r = $s | Assert-X509ChainStatus
            $r | Should -BeNullOrEmpty
        }
        It 'accomodates array' {
            $a = [System.Security.Cryptography.X509Certificates.X509ChainStatus[]]::new(2)
            $a[0] = $a[1] = $s
            Assert-X509ChainStatus -ChainStatus $a
        }
    }
    Context 'empty' {
        $s = [System.Security.Cryptography.X509Certificates.X509ChainStatus[]]::new(0)
        It 'throws' {
            { Assert-X509ChainStatus -ChainStatus $s } |
                Should -Throw 'ChainStatus is null'
        }
    }
    Context 'null' {
        It 'throws' {
            { Assert-X509ChainStatus -ChainStatus $s } |
                Should -Throw 'ChainStatus is null'
        }
    }
    Context 'error' {
        It 'throws' {
            { 
                Assert-X509ChainStatus -ChainStatus ([System.Security.Cryptography.X509Certificates.X509ChainStatus]@{
                    Status = [System.Security.Cryptography.X509Certificates.X509ChainStatusFlags]::CtlNotSignatureValid
                    StatusInformation = 'this_status_info'
                })
            } |
                Should -Throw 'this_status_info'
        }
    }
}