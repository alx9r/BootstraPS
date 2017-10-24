Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

. "$PSScriptRoot\..\helpers.ps1"

Describe 'Certificate Validation' {
    Set-SpManagerPolicy -Strict
    It 'fails' {
        try
        {
            'https://sha1-intermediate.badssl.com/' | 
                Save-WebFile -Path ([System.IO.Path]::GetTempFileName()) -CertificateValidator {
                    New-X509Chain |
                        Update-X509Chain $_.certificate |
                        Get-X509Intermediate |
                        Get-X509SignatureAlgorithm |
                        % {
                            $_ | Assert-OidFips180_4
                            $_ | Assert-OidNotSha1
                        }
                }
        }
        catch
        {
            $threw = $true
            $e = $_.Exception
        }
        $threw | Should -Be $true
        $e | CoalesceExceptionMessage |
            Should -Match 'Signature algorithm is sha1RSA'
    }
}