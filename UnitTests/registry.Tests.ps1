Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

InModuleScope Bootstraps {
Describe Get-VolumeString {
    It '<i> returns <o>' -TestCases @(
        @{i='c:';o='c'}
        @{i='c:\path';o='c'}
        @{i='path';o=$null}
    ) {
        param($i,$o)
        $r = $i | Get-VolumeString
        $r | Should -Be $o
    }
}
Describe Get-PathWithoutVolume {
    It '<i> returns <o>' -TestCases @(
        @{i='c:';o=$null}
        @{i='c:\path';o='path'}
        @{i='path';o='path'}
    ) {
        param($i,$o)
        $r = $i | Get-PathWithoutVolume
        $r | Should -Be $o
    }
    It 'throws' {
        try
        {
            '::' | Get-PathWithoutVolume
        }
        catch
        {
            $e = $_.Exception
        }
        $e.Message | Should -Match 'Path'
        $e.Message | Should -Match $i
        $e.InnerException.Message | Should -Match 'Too many'
    }
}
Describe Get-RegistryHive {
    It 'returns' {
        $r = Get-RegistryHive HKLM
        $r | Should -BeOfType ([Microsoft.Win32.RegistryKey])
        $r.Dispose()
        $r.Count | Should -Be 1
    }
    It 'throws' {
        { 'bogus' | Get-RegistryHive } |
            Should throw 'unknown'
    }
}
}