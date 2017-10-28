Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

. "$PSScriptRoot\..\helpers.ps1"

Describe 'Certificate Validation' {
    Set-SpManagerPolicy -Strict
    It 'fails' {
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