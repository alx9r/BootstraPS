Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

. "$PSScriptRoot\..\helpers.ps1"

Describe 'certificate permissiveness' {
    Set-SpManagerPolicy -Strict
    Context 'fail without additional validation' {
        It '<u>' -TestCases @(
            @{u='https://expired.badssl.com'}
            @{u='https://wrong.host.badssl.com'}
            @{u='https://self-signed.badssl.com'}
            @{u='https://untrusted-root.badssl.com/'}
        ) {
            param($u,$cv)
            try
            {
                $u | Save-WebFile ([System.IO.Path]::GetTempFileName())
            }
            catch
            {
                $threw = $true
                $_.Exception | CoalesceExceptionMessage |
                    Should -Match 'certificate is invalid'
            }
            $threw | Should -Be $true
        }
    }
    Context 'succeed without additional validation' {
        It '<u>' -TestCases @(
            @{u='https://sha1-intermediate.badssl.com/'}
            @{u='https://revoked.badssl.com'}
            @{u='https://pinning-test.badssl.com'}
            @{u='https://invalid-expected-sct.badssl.com/'}
        ) {
            param($u,$cv)
            $u | Save-WebFile ([System.IO.Path]::GetTempFileName())
        }
    }
}