$bspsUri = 'https://raw.githubusercontent.com/alx9r/BootstraPS/master/BootstraPS.ps1'
Describe 'BootstraPS.ps1 as a download' {
    It 'downloads' {
        $r = Invoke-WebRequest $bspsUri
        $r.Content | Should -Not -BeNullOrEmpty
    }
    Context 'byte order marks after download' {
        It 'Downloaded <n> file''s first character is not a byte order mark' -TestCases @(
            @{n='BootstraPS.ps1';u='https://raw.githubusercontent.com/alx9r/BootstraPS/master/BootstraPS.ps1'}
            @{n='utf-8.txt'     ;u='https://raw.githubusercontent.com/alx9r/BootstraPS/master/Resources/utf-8.txt' }
        ) {
            param($n,$u)
            $r = Invoke-WebRequest $u
            [int]$r.Content[0] | Should -Not -Be 65279
        }
        It 'Downloaded <n> file''s first character is a byte order mark' -TestCases @(
            @{n='utf-8-BOM.txt'     ;u='https://raw.githubusercontent.com/alx9r/BootstraPS/master/Resources/utf-8-bom.txt' }
        ) {
            param($n,$u)
            $r = Invoke-WebRequest $u
            [int]$r.Content[0] | Should -Be 65279
        }
    }
    Context 'functions' {
        It 'invoke expression succeeds' {
            Invoke-WebRequest $bspsUri |
                % Content |
                Invoke-Expression
        }
        It 'function is created' {
            Remove-Item Function:\Import-WebModule -ErrorAction SilentlyContinue
            Invoke-WebRequest $bspsUri |
                % Content |
                Invoke-Expression
            Get-Item Function:\Import-WebModule |
                Should -Not -BeNullOrEmpty
        }
    }
}