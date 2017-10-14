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

function New-MemoryStream
{
    try
    {
        [System.IO.MemoryStream]::new()
    }
    catch
    {
        throw $_.Exception
    }
}

function New-Formatter
{
    try
    {
        [System.Runtime.Serialization.Formatters.Binary.BinaryFormatter]::new()
    }
    catch
    {
        throw $_.Exception
    }
}

function Serialize
{
    param
    (
        [Parameter(Position = 1)]
        [System.IO.Stream]
        $Stream = (New-MemoryStream),

        [Parameter(Position=2)]
        [System.Runtime.Serialization.Formatters.Binary.BinaryFormatter]
        $Formatter = (New-Formatter),

        [Parameter(ValueFromPipeline,Mandatory)]
        $InputObject
    )
    process
    {
        try
        {
            $Formatter.Serialize($Stream,$InputObject)
            $Stream
        }
        catch
        {
            throw [System.Exception]::new(
                "InputObject: $InputObject",
                $_.Exception
            )
        }
    }
}

function Deserialize
{
    param
    (
        [Parameter(Position=1,Mandatory)]
        [type]
        $Type,

        [Parameter(Position=2)]
        [System.Runtime.Serialization.Formatters.Binary.BinaryFormatter]
        $Formatter = (New-Formatter),
        
        [Parameter(ValueFromPipeline,Mandatory)]
        [System.IO.Stream]
        $Stream
    )
    process
    {
        try
        {
            $Stream.Position = 0
            $object = $Formatter.Deserialize($Stream)
            if ( $object -is $Type )
            {
                $object
            }
            else
            {
                [System.Convert]::ChangeType($object,$Type)
            }
        }
        catch
        {
            throw [System.Exception]::new(
                "Type: $Type",
                $_.Exception
            )
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
        $propertyNames = @(
            'certificate'
            #'sender'  # this type is not serializable
            #'chain'   # "
            'sslPolicyErrors'
        )
        $streams = @{}
        {
            foreach ( $propertyName in $propertyNames )
            {
                $streams.$propertyName = [System.IO.MemoryStream]::new()
                [System.Runtime.Serialization.Formatters.Binary.BinaryFormatter]::new().Serialize(
                    $streams.$propertyName,
                    $_.$propertyName
                )
            }
        } |
            New-CertificateValidationCallback |
            New-HttpClient |
            Start-Download $Uri |
            % {
                try
                {
                    $_ | Wait-Task
                }
                catch
                {
                    if ( $_.Exception.InnerException.InnerException.InnerException.InnerException -notmatch
                         'certificate is invalid' )
                    {
                        throw $_.Exception
                    }                       
                }
            }
        
        [pscustomobject]@{
            certificate = $streams.certificate | Deserialize ([X509Certificate])
            sslPolicyErrors = $streams.sslPolicyErrors | 
                                                 Deserialize ([System.Net.Security.SslPolicyErrors])
        }
    }
}