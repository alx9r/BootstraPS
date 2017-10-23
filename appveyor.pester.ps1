# This file is adapted from https://github.com/RamblingCookieMonster/PSDiskPart/

# The MIT License (MIT)
# 
# Copyright (c) 2015 Warren F.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# This script will invoke pester tests
# It should invoke on PowerShell v2 and later
# We serialize XML results and pull them in appveyor.yml

#If Finalize is specified, we collect XML output, upload tests, and indicate build errors
param([switch]$Finalize)

#Run a test with the current version of PowerShell
if(-not $Finalize)
{
    # Dump some versions to the console
    Write-Host '=== OS Version ==='
    Write-Host ([System.Environment]::OSVersion | Out-String)
    Write-Host '=== PSVersionTable ==='
    Write-Host ($PSVersionTable | Out-String)

    Write-Host '=== Git ==='
    Get-Command git.exe
    git --version

    #Initialize some variables, move to the project root
    $PSVersion = $PSVersionTable.PSVersion.Major
    $TestFile = "TestResultsPS$PSVersion.xml"
    $ProjectRoot = $ENV:APPVEYOR_BUILD_FOLDER
    Set-Location $ProjectRoot

    #Set PSModulePath to include one level up from the project root
    $myModulePath = [System.IO.Path]::GetFullPath("$ProjectRoot\..")
    if (($env:PSModulePath.Split(';') | select -First 1) -ne $myModulePath) {
        $env:PSModulePath = "$myModulePath;$env:PSModulePath"
    }

    Write-Host '=== PSModulePath ==='
    Write-Host ($env:PSModulePath.Split(';') | Out-String)

    Write-Host '=== Get-Module -ListAvailable ==='
    Write-Host (Get-Module -ListAvailable | sort Name,Version | select Name,Version | Format-Table | Out-String)

    Write-Host '=== invoke .\prerequisites.ps1 ==='
    Write-Host (. "$PSScriptRoot\prerequisites.ps1" | Out-String)

    Write-Host '=== Pester Version ==='
    Write-Host (Get-Module Pester).Version.ToString()

    Write-Host '=== .Net Version ==='
    Write-Host (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\' | Out-String)

    Write-Host '=== Schannel Config ==='
    Write-Host (Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL -Recurse | Out-String)

    Invoke-Pester -Path "$ProjectRoot" -OutputFormat NUnitXml -OutputFile "$ProjectRoot\$TestFile" -PassThru |
        Export-Clixml -Path "$ProjectRoot\PesterResults$PSVersion.xml"
}
#If finalize is specified, check for failures and 
else
{
    #Show status...
        $AllFiles = Get-ChildItem -Path $ProjectRoot\*Results*.xml | Select -ExpandProperty FullName
        "`n`tSTATUS: Finalizing results`n"
        "COLLATING FILES:`n$($AllFiles | Out-String)"

    #Upload results for test page
        Get-ChildItem -Path "$ProjectRoot\TestResultsPS*.xml" | Foreach-Object {
        
            $Address = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
            $Source = $_.FullName

            "UPLOADING FILES: $Address $Source"

            (New-Object 'System.Net.WebClient').UploadFile( $Address, $Source )
        }

    #What failed?
        $Results = @( Get-ChildItem -Path "$ProjectRoot\PesterResults*.xml" | Import-Clixml )
            
        $FailedCount = $Results |
            Select -ExpandProperty FailedCount |
            Measure-Object -Sum |
            Select -ExpandProperty Sum
    
        if ($FailedCount -gt 0) {

            $FailedItems = $Results |
                Select -ExpandProperty TestResult |
                Where {$_.Passed -notlike $True}

            "FAILED TESTS SUMMARY:`n"
            $FailedItems | ForEach-Object {
                $Test = $_
                [pscustomobject]@{
                    Describe = $Test.Describe
                    Context = $Test.Context
                    Name = "It $($Test.Name)"
                    Result = $Test.Result
                }
            } |
                Sort Describe, Context, Name, Result |
                Format-List

            throw "$FailedCount tests failed."
        }
}