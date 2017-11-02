Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

. "$PSScriptRoot\..\helpers.ps1"

Describe Assert-X509NotRevoked {
    It 'throws' {
        $c = Import-Clixml $PSScriptRoot\..\Resources\certificates\revoked.xml
        { $c | Assert-X509NotRevoked } |
            Should -Throw 'revoked'
    }
}

Describe Save-WebFile {
    Set-SpManagerPolicy -Strict
    It 'certificate validation failure' {
        try
        {
            'https://github.com/alx9r/bootstraps' | 
                Save-WebFile -Path ([System.IO.Path]::GetTempFileName()) -CertificateValidator {
                    throw 'validation failed'
                }
        }
        catch
        {
            $threw = $true
            $e = $_.Exception
        }
        $threw | Should -Be $true
        $e | CoalesceExceptionMessage |
            Should -Match 'validation failed'
    }
}