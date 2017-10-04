. "$PSScriptRoot\BootstraPS.ps1"

Describe 'Import-WebModule' {
    It 'imports a module' {
        Get-Module ModuleA | Remove-Module -Force
        'ModuleA' |
            Import-WebModule @{
                ModuleA = 'https://raw.githubusercontent.com/alx9r/BootstraPS/master/Resources/ModuleA.zip'
            }
        Get-Module ModuleA | Should -not -BeNullOrEmpty
        Get-Item Function:\Invoke-ModuleACommand | Should -not -BeNullOrEmpty
    }
    It 'imports nested modules' {
        Get-Module ModuleA,ModuleB | Remove-Module -Force
        'ModuleB' |
            Import-WebModule @{
                ModuleA = 'https://raw.githubusercontent.com/alx9r/BootstraPS/master/Resources/ModuleA.zip'
                ModuleB = 'https://raw.githubusercontent.com/alx9r/BootstraPS/master/Resources/ModuleB.zip'
        }

        Get-Module ModuleA | Should -not -BeNullOrEmpty
        Get-Module ModuleB | Should -not -BeNullOrEmpty
        Get-Item Function:\Invoke-ModuleACommand | Should -not -BeNullOrEmpty
        Get-Item Function:\Invoke-ModuleBCommand | Should -not -BeNullOrEmpty
    }
}