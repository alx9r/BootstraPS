Describe 'Type of DWord from GetValue()' {
    $h = @{}
    $guid = [guid]::NewGuid().Guid
    $testPath = "HKCU:\Test\$guid"
    It 'setup' {
        New-Item $testPath -Force -ErrorAction SilentlyContinue
    }
    It 'open key' {
        $h.key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Test\$guid",$true)
    }
    It 'write DWord' {
        $h.key.SetValue('propertyName',0xFFFFFFFF,[Microsoft.Win32.RegistryValueKind]::DWord)
    }
    It 'read DWord' {
        $h.r = $h.key.GetValue('propertyName')
    }
    It 'is of type int32' {
        $h.r | Should -BeOfType ([int32])
    }
    It 'dispose key' {
        $h.key.Dispose()
    }
    It 'teardown' {
        Remove-Item $testPath
    }
}