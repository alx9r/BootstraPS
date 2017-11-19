. "$PSScriptRoot\webLoad.ps1"
Set-SchannelPolicy -Strict
Set-SpManagerPolicy -Strict
Import-WebModule 'https://github.com/pester/Pester/archive/4.0.8.zip' 'Pester.psd1' -PassThru
Import-WebModule 'https://github.com/alx9r/Assert/archive/7847b2dadc50f8ba0fe6b3b4c9e4dad0de47b17d.zip' -PassThru
Remove-Module BootstraPS
