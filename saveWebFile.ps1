Add-Type -Path "$PSScriptRoot\types.cs" -ReferencedAssemblies 'Microsoft.CSharp.dll'
Add-Type -AssemblyName System.Net.Http.WebRequest

function New-CertificateValidationCallback
{
    param
    (
        [Parameter(ValueFromPipeline, Mandatory)]
        [AllowNull()]
        [scriptblock]
        $ScriptBlock
    )
    process
    {
        try
        {
            if ( $null -eq $ScriptBlock )
            {
                return $null
            }
            [CertificateValidator]::new($ScriptBlock).Delegate
        }
        catch
        {
            throw [System.Exception]::new(
                "ScriptBlock: $ScriptBlock",
                $_.Exception
            )
        }
    }
}

function New-HttpClient
{
    param
    (
        [Parameter(ValueFromPipeline)]
        [AllowNull()]
        [System.Net.Security.RemoteCertificateValidationCallback]
        $CertificateValidationCallback
    )
    process
    {
        try
        {
            $handler = [System.Net.Http.WebRequestHandler]::new()
            $handler.ServerCertificateValidationCallback = $CertificateValidationCallback
            [System.Net.Http.HttpClient]::new($handler)
        }
        catch
        {
            throw $_.Exception
        }
    }
}

function Start-Download
{
    param
    (
        [Parameter(Position = 1, Mandatory)]
        [uri]
        $Uri,

        [Parameter(ValueFromPipeline, Mandatory)]
        [System.Net.Http.HttpClient]
        $HttpClient
    )
    process
    {
        try
        {
            $response = $HttpClient.GetAsync($Uri)
            $response
        }
        catch
        {
            throw [System.Exception]::new(
                "Uri: $Uri",
                $_.Exception
            )
        }
    }
}

function Get-ContentReader
{
    param
    (
        [Parameter(ValueFromPipeline, Mandatory)]
        [System.Threading.Tasks.Task[System.Net.Http.HttpResponseMessage]]
        $HttpResponseMessage
    )
    process
    {
        try
        {
            $HttpResponseMessage.get_Result().Content.ReadAsStreamAsync()
        }
        catch
        {
            throw $_.Exception
        }
    }
}

function New-FileStream
{
    param
    (
        [Parameter(Position = 1, Mandatory)]
        [System.IO.FileMode]
        $FileMode,

        [Parameter(ValueFromPipeline, Mandatory)]
        [string]
        $Path
    )
    process
    {
        try
        {
            $fileStream = [System.IO.File]::Open($Path,$FileMode)
            $fileStream
        }
        catch
        {
            throw [System.Exception]::new(
                ("Path: $Path",
                 "FileMode: $FileMode" -join [System.Environment]::NewLine),
                $_.Exception
            )
        }
        finally
        {
            $fileStream.Dispose()
        }
    }
}

function Connect-Stream
{
    param
    (
        [Parameter(Position = 1, Mandatory)]
        [System.IO.Stream]
        $Destination,
        
        [Parameter(ValueFromPipeline, Mandatory)]
        [System.Threading.Tasks.Task[System.IO.Stream]]
        $Source
    )
    process
    {
        $Source.Result.CopyToAsync($Destination)
    }
}

function Wait-Task
{
    param
    (
        [Parameter(ValueFromPipeline, Mandatory)]
        [System.Threading.Tasks.Task]
        $Task
    )
    begin
    {
        $tasks = [System.Collections.ArrayList]::new()
    }
    process
    {
        $tasks.Add($Task) | Out-Null
    }
    end
    {
        try
        {
            [System.Threading.Tasks.Task]::WaitAll($tasks)    
        }
        catch
        {
            throw $_.Exception
        }
    }
}

function Save-WebFile
{
    param
    (
        [scriptblock]
        $CertificateValidator,

        [Parameter(Position = 1,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [string]
        $Path,

        [Parameter(ValueFromPipeline, Mandatory)]
        [uri]
        $Uri
    )
    process
    {
        $Path | 
            New-FileStream Create |
            % {
                $CertificateValidator | 
                    New-CertificateValidationCallback |
                    New-HttpClient |
                    Start-Download $Uri |
                    Get-ContentReader |
                    Connect-Stream $_ |
                    Wait-Task
            }
    }
}

function Get-ValidationObject
{
    param
    (
        [Parameter(ValueFromPipeline, Mandatory)]
        [uri]
        $Uri
    )
    process
    {
        $h = @{}
        {$h.DollarBar = $_ } |
            New-CertificateValidationCallback |
            New-HttpClient |
            Start-Download $Uri |
            % {
                try
                {
                    $_ | Wait-Task
                }
                catch {}
                finally
                {
                    $h.DollarBar
                }
            }
    }
}