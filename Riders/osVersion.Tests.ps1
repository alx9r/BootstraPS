Describe 'Windows Version' {
    It 'at least Windows 8.1/Server 2012R2' {
        [System.Environment]::OSVersion.Version -ge '6.3' | Should -be $true
    }
}