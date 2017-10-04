Describe 'byte order marks after download' {
    It 'Downloaded <n> file''s first character is not a byte order mark' -TestCases @(
        @{n='BootstraPS.ps1';u='https://raw.githubusercontent.com/alx9r/BootstraPS/master/BootstraPS.ps1'}
        @{n='utf-8.txt'     ;u='https://raw.githubusercontent.com/alx9r/BootstraPS/master/Resources/utf-8.txt' }
    ) {
        param($n,$u)
        $r = Invoke-WebRequest $u
        [int]$r.Content[0] | Should not be 65279
    }
    It 'Downloaded <n> file''s first character is a byte order mark' -TestCases @(
        @{n='utf-8-BOM.txt'     ;u='https://raw.githubusercontent.com/alx9r/BootstraPS/master/Resources/utf-8-bom.txt' }
    ) {
        param($n,$u)
        $r = Invoke-WebRequest $u
        [int]$r.Content[0] | Should be 65279
    }
}