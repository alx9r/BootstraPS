Describe 'Invoke-WebRequest badssl' {
    It 'throws on <u>' -TestCases @(
        # per https://badssl.com/dashboard/

        @{u='https://expired.badssl.com'}
        @{u='https://wrong.host.badssl.com'}
        @{u='https://self-signed.badssl.com'}
        @{u='https://untrusted-root.badssl.com/'}
        @{u='https://sha1-intermediate.badssl.com/'}
        @{u='https://rc4.badssl.com/'}
        @{u='https://rc4-md5.badssl.com/'}
        @{u='https://dh480.badssl.com/'}
        @{u='https://dh512.badssl.com/'}
        @{u='https://dh1024.badssl.com/'}
        @{u='https://superfish.badssl.com/'}
        @{u='https://edellroot.badssl.com/'}
        @{u='https://dsdtestprovider.badssl.com/'}
        @{u='https://preact-cli.badssl.com/' }
        @{u='https://webpack-dev-server.badssl.com/'}
        @{u='https://null.badssl.com/'}
          
        @{u='https://revoked.badssl.com'}
        @{u='https://pinning-test.badssl.com'}
        @{u='https://invalid-expected-sct.badssl.com/'}
        @{u='https://ssl-v2.badssl.com:1002'}
        @{u='https://ssl-v3.badssl.com:1003'}
    ) {
        param($u)
        try
        {
            Invoke-WebRequest $u
        }
        catch
        {
            $threw = $true
            $_.Exception.Message | Should -Match '(Could not establish trust relationship|Could not create SSL/TLS secure channel)'
        }
        $threw | Should -Be $true
    }
}