. "$PSScriptRoot\webLoad.ps1"

Import-WebModule 'https://github.com/pester/Pester/archive/4.0.8.zip' 'Pester.psd1' -PassThru

Write-Host '=== Set-SchannelPolicy -Strict ==='
Set-SchannelPolicy -Strict

Remove-Module BootstraPS