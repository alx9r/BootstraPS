Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

. "$PSScriptRoot\..\helpers.ps1"

Describe Save-WebFile {
    Set-SpManagerPolicy -Strict
    $uri = 'https://github.com/alx9r/BootstraPS/archive/master.zip'
    Context 'downloads' {
        $h=@{
            swfFileName = [System.IO.Path]::GetTempFileName()
            iwrFileName = [System.IO.Path]::GetTempFileName()
        }
        Context Save-WebFile {
            It 'downloads' {
                $uri | Save-WebFile $h.swfFileName
            }
        }
        Context Invoke-WebRequest {
            It 'downloads' {
                Invoke-WebRequest $uri -OutFile $h.iwrFileName
            }
        }
        Context 'validate' {
            It 'file <n> exists' -TestCases @(
                @{n='swfFileName'}
                @{n='iwrFileName'}
            ) {
                param($n)
                Test-Path $h.$n -PathType Leaf |
                    Should -Be $true
            }
            It 'file sizes match' {
                (Get-Item $h.iwrFileName).Length |
                    Should -Be (Get-Item $h.swfFileName).Length
            }
            It 'hashes match' {
                (Get-FileHash $h.iwrFileName).Hash |
                    Should -be (Get-FileHash $h.swfFileName).Hash
            }
        }
        It 'cleanup' {
            Remove-Item $h.iwrFileName -ea SilentlyContinue
            Remove-Item $h.swfFileName -ea SilentlyContinue
        }
    }
    Context 'validate certificate' {
        Context 'false' {
            try
            {
                $uri | Save-WebFile ([System.IO.Path]::GetTempFileName()) -Cert {$false}
            }
            catch
            {
                $e = $_.Exception
            }
            It 'throws' {
                $e | Should -not -BeNullOrEmpty
            }
            It 'message' {
                $e | 
                    CoalesceExceptionMessage |
                    Should -Match 'cert.*invalid'
            }
        }
    }
}

Describe Get-ValidationObject {
    $r = 'https://github.com' | Get-ValidationObject
    It 'returns' {
        $r | Should -Not -BeNullOrEmpty
        $r | measure | % Count | Should -Be 1
        $r | Should -BeOfType ([psobject])
    }
    It 'has property <n>' -TestCases @(
        #@{n='sender';         t=[System.Net.HttpWebRequest]}
        @{n='certificate';    t=[System.Security.Cryptography.X509Certificates.X509Certificate2]}
        #@{n='chain';          t=[System.Security.Cryptography.X509Certificates.X509Chain]}
        @{n='sslPolicyErrors';t=[System.Net.Security.SslPolicyErrors]}
    ) {
        param($n,$t)
        $r.$n | Should -BeOfType $t
    }
}