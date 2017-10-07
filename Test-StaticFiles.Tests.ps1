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
            $i++
            if ( $h.new[$i] -ne $h.existing[$i] )
            {
                throw "Line $i of $filename is not as expected.  Expected $($h.new[$i])"
            }
        }
    }
}
}