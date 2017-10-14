Describe 'Invoke-WebRequest certificate checking' {
    It 'throws on <n>' -TestCases @(
        # per https://badssl.com/dashboard/

        @{n='expired';             u='https://expired.badssl.com'}
        @{n='wrong.host';          u='https://wrong.host.badssl.com'}
        @{n='self-signed';         u='https://self-signed.badssl.com'}
        @{n='untrusted-root';      u='https://untrusted-root.badssl.com/'}
        @{n='sha1-intermediate';   u='https://sha1-intermediate.badssl.com/'}
        @{n='rc4';                 u='https://rc4.badssl.com/'}
        @{n='rc4-md5';             u='https://rc4-md5.badssl.com/'}
        @{n='dh480';               u='https://dh480.badssl.com/'}
        @{n='dh512';               u='https://dh512.badssl.com/'}
        @{n='dh1024';              u='https://dh1024.badssl.com/'}
        @{n='superfish';           u='https://superfish.badssl.com/'}
        @{n='edellroot';           u='https://edellroot.badssl.com/'}
        @{n='dsdtestprovider';     u='https://dsdtestprovider.badssl.com/'}
        @{n='preact-cli';          u='https://preact-cli.badssl.com/' }
        @{n='webpack-dev-server';  u='https://webpack-dev-server.badssl.com/'}
        @{n='null';                u='https://null.badssl.com/'}
                                   
        @{n='revoked';             u='https://revoked.badssl.com'}
        @{n='pinning-test';        u='https://pinning-test.badssl.com'}
        @{n='invalid-expected-sct';u='https://invalid-expected-sct.badssl.com/'}
    ){
        param($n,$u)
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