. "$PSScriptRoot\helpers.ps1"

foreach ( $values in @(
    @('webLoad.ps1','New-WebLoadPs1'),
    @('readme.md','New-ReadmeMd')
))
{
$filename,$CommandName = $values
Describe $fileName {
    $h = @{}
    It 'get new' {
        $h.new = . $CommandName
        $h.new | Should -Not -BeNullOrEmpty
    }
    It 'get existing' {
        $h.existing = Get-Content "$PSScriptRoot\$filename"
    }
    It 'same number of lines' {
        $h.existing.Count | Should -Be $h.new.Count
    }
    It 'lines match' {
        $i=0
        foreach($line in $h.new)
        {
            try
            {
                $h.new[$i] | Should -be $h.existing[$i]
            }
            catch
            {
                throw [System.Exception]::new(
                    "Line $($i+1) of $filename is not as expected.",
                    $_.Exception
                )
            }
            $i++
        }
    }
}
}