@(
    'sha256'
    'sha384'
    'sha512'
    'rsa2048'
    'ecc256'
    'ecc384'
    'sha1-intermediate',
    'expired'
    'wrong.host'
    'self-signed'
    'untrusted-root'
    'sha1-intermediate'
    'revoked'
    'pinning-test'
    'invalid-expected-sct'
) |
    % {
        $address = "$_.badssl.com"
        "https://$address" |
            Get-ValidationObject | 
            % Certificate | 
            Export-Clixml $PSScriptRoot\$_.xml
    }