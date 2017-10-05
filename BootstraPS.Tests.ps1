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
}