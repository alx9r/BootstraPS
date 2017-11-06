Describe 'character encoding' {
    $files = Get-ChildItem $PSScriptRoot -Recurse -File -Exclude *bom*.*,*Pester*.xml
    It 'files do not use a UTF-8 byte order mark' {
        foreach ( $file in $files )
        {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            try
            {
                $bytes[0..2] | Should -Not -Be 0xEF,0xBB,0xBF
            }
            catch
            {
                throw [System.Exception]::new(
                    $file.FullName,
                    $_.Exception
                )
            }
        }
    }
    It '<n> uses LF linefeed endings' -TestCases @(
        @{ n = "$PSScriptRoot\BootstraPS.psm1" }
        @{ n = "$PSScriptRoot\readme.md" }
        @{ n = "$PSScriptRoot\readme.md.source" }
        @{ n = "$PSScriptRoot\webLoad.ps1" }
        @{ n = "$PSScriptRoot\webLoad.ps1.source" }
    ) {
        param ($n)

        if ( (Get-Content $n -Raw -ea Stop) -match "\r\n" )
        {
            throw "$n has CRLF line endings"
        }
    }
}