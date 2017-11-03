Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

. "$PSScriptRoot\..\helpers.ps1"

Describe 'certificate permissiveness' {
    Set-SpManagerPolicy -Strict
    Context 'fail without additional validation' {
        It '<u>' -TestCases @(
            @(
                # Not Secure
                'expired'
                'self-signed'
                'untrusted-root'
                'no-san'
                'null'
                ## known-bad
                'dsdtestprovider'
                'edellroot'
                'mitm-software'
                'preact-cli'
                'superfish'
                'webpack-dev-server'
            ) |
                % {@{u="https://$_.badssl.com"}}
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
                    Should -Match '(certificate is invalid|Could not create)'
            }
            $threw | Should -Be $true
        }
    }
    Context 'succeed without additional validation' {
        It '<u>' -TestCases @(
            @(
                # Bad Certificates
                'pinning-test'      # If we were a browser or any other thing that had a long
                                    # lifecycle, this should fail.
                'invalid-expected-sct' # <-- requires intervention
                'sha1-intermediate'    # <-- requires intervention
                'revoked'              # <-- requires intervention

                # Secure but Weird
                '1000-sans'
                 #'10000-sans' # causes failure, also causes failure on Chrome
                'rsa8192'
                'no-subject'
                'no-common-name'
                'incomplete-chain'

                # Secure
                'sha256'
                'sha384'
                'sha512'
                'rsa2048'
                'ecc256'
                'ecc384'
                 #'mozilla-modern' # causes failure, succeeds on Chrome
            ) |
                % {@{u="https://$_.badssl.com"}}
        ) {
            param($u,$cv)
            $u | Save-WebFile ([System.IO.Path]::GetTempFileName())
        }
    }
}