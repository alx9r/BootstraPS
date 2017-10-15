Add-Type -AssemblyName System.Net.Http
$uri = 'https://github.com/alx9r/BootstraPS/archive/master.zip'
Describe 'Download File' {
    $h=@{
        iwrFileName = [System.IO.Path]::GetTempFileName()
        hcFileName = [System.IO.Path]::GetTempFileName()
    }
    Context 'httpclient' {
        It 'response and size' {
            $client = [System.Net.Http.HttpClient]::new()
            $h.responseTask = $client.GetAsync($uri,[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
            $h.responseTask.Wait()
            $h.responseTask.Result.Content.Headers.ContentLength |
                Should -Not -BeNullOrEmpty
        }
        It 'content' {
            $srcTask = $h.responseTask.Result.Content.ReadAsStreamAsync()
            $filename = [System.IO.Path]::GetTempFileName()
            & {
                $dstStream = [System.IO.File]::Open($h.hcFileName,[System.IO.FileMode]::Create)
                $dstStream
                $dstStream.Dispose() | Out-Null
            } |
            % {
                $copyTask = $srcTask.Result.CopyToAsync($_)
                $srcTask.Wait()
                $copyTask.Wait()
            }
        }
    }
    Context 'Invoke-WebRequest' {
        It 'downloads' {
            Invoke-WebRequest $uri -OutFile $h.iwrFileName
        }
    }
    Context 'validate' {
        It 'file <n> exists' -TestCases @(
            @{n='iwrFileName'}
            @{n='hcFileName'}
        ) {
            param($n)
            Test-Path $h.$n -PathType Leaf |
                Should -Be $true
        }
        It 'file sizes match' {
            (Get-Item $h.iwrFileName).Length |
                Should -Be (Get-Item $h.hcFileName).Length
        }
        It 'hashes match' {
            (Get-FileHash $h.iwrFileName).Hash |
                Should -be (Get-FileHash $h.hcFileName).Hash
        }
    }
    It 'cleanup' {
        Remove-Item $h.iwrFileName -ea SilentlyContinue
        Remove-Item $h.hcFileName -ea SilentlyContinue
    }
}