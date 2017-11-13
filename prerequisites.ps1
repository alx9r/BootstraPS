. "$PSScriptRoot\webLoad.ps1"
Set-SchannelPolicy -Strict
Set-SpManagerPolicy -Strict
Import-WebModule 'https://github.com/pester/Pester/archive/4.0.8.zip' 'Pester.psd1' -PassThru
Remove-Module BootstraPS
