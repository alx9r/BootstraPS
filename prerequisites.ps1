. "$PSScriptRoot\webLoad.ps1"

Import-WebModule 'https://github.com/pester/Pester/archive/4.0.8.zip' 'Pester.psd1' -PassThru

Write-Host '=== Disabling Schannel Ciphers, Hashes, and KeyExchangeAlgorithms ==='
[BootstraPS.Schannel.Ciphers].GetEnumValues() |
    ? { $_ -match 'RC4' } |
    % {
        Write-Host "Disabling Cipher $_"
        Clear-SchannelRegistryEntry Enabled -Cipher $_
    }
Write-Host 'Disabling Hash MD5'
Clear-SchannelRegistryEntry Enabled -Hash MD5
Write-Host 'Disabling KeyExchangeAlgorithm'
Clear-SchannelRegistryEntry Enabled -KeyExchangeAlgorithm DH


Remove-Module BootstraPS