Get-Module Bootstraps | Remove-Module;
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

InModuleScope Bootstraps {
Describe Save-WebFile {
    Mock Assert-SchannelPolicy -Verifiable
    Mock Assert-SpManagerPolicy -Verifiable
    Mock Assert-Https -Verifiable
    Mock New-FileStream { [System.IO.MemoryStream]::new() }
    Mock New-CertificateValidationCallback -Verifiable
    @{ s=[BootstraPS.Policy.Strictness]::Normal;              http=$false; restricted = $false; test = { $null -eq $SkipBuiltInSslPolicyCheck } },
    @{ s=[BootstraPS.Policy.Strictness]::Strict;              http=$false; restricted = $true;  test = { $null -eq $SkipBuiltInSslPolicyCheck } },
    @{ s=[BootstraPS.Policy.Strictness]::DangerousPermissive; http=$true;  restricted = $false; test = { $true -eq $SkipBuiltInSslPolicyCheck } } |
    % {
        $s = $_.s
        $http = $_.http
        $restricted = $_.restricted
        $test = $_.test
        Context "Strictness : $s" {
            'http://uri' | Save-WebFile 'dest' -SecurityPolicy $s
            It "restricted: $restricted" {
                Assert-MockCalled Assert-SchannelPolicy  -Times ([int]$restricted) -Exactly
                Assert-MockCalled Assert-SpManagerPolicy -Times ([int]$restricted) -Exactly
            }
            It "http allowed: $http" {
                Assert-MockCalled Assert-Https -Times ([int](-not $http)) -Exactly {
                    $Uri -eq 'http://uri'
                }
            }
            It "test: {$test}" {
                Assert-MockCalled New-CertificateValidationCallback -Times 1 -Exactly -ParameterFilter $test
            }
        }
    }
}
}