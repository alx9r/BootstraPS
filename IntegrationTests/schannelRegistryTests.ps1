Describe 'Schannel Registry cycle' {
    $h = @{}
    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'
    $splat = @{
        EnableType = [BootstraPS.Schannel.EnableType]::Enabled
        Protocol =    [BootstraPS.Schannel.Protocols]::TLS_1_2
        Role =             [BootstraPS.Schannel.Role]::Client
    }
    It 'get original' {
        $h.original = Get-SchannelRegistryEntry @splat
    }
    It 'set' {
        Set-SchannelRegistryEntry @splat
    }
    It 'test' {
        $r = Test-SchannelRegistryEntry @splat
        $r | Should -Be $true
    }
    It 'test (Get-ItemPropertyValue)' {
        $r = Get-ItemPropertyValue -LiteralPath $path -Name Enabled
        $r | Should -be ([uint32]'0xFFFFFFFF')
    }
    It 'clear' {
        Clear-SchannelRegistryEntry @splat
    }
    It 'test' {
        $r = Test-SchannelRegistryEntry @splat
        $r | Should -be $false
    }
    It 'test (Get-ItemPropertyValue)' {
        $r = Get-ItemPropertyValue -LiteralPath $path -Name Enabled
        $r | Should -be 0x0
    }
    It 'restore' {
        $h.original | Set-RegistryProperty
    }
}