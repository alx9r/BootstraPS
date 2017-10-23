Describe 'Windows Version' {
    It 'at least Windows 8/Server 2012' {
        [System.Environment]::OSVersion.Version -ge '6.2' | Should -be $true
    }
}