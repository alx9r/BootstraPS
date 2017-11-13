Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"
try
{
    & (Get-Module Bootstraps) {
        'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL' |
            ConvertTo-Win32RegistryPathArgs |
            Open-Win32RegistryKey -Writable | Afterward -Dispose |
            Out-Null
    }
    . "$PSScriptRoot\schannelRegistryTests.ps1"
}
catch
{
    if ( $_.Exception.InnerException -notmatch 'access is not allowed' )
    {
        throw
    }
}