
#Requires -Version 5

function Afterward
{
    [CmdletBinding(DefaultParameterSetName='scriptblock')]
    param
    (
        [Parameter(ParameterSetName = 'scriptblock',
                   Position = 1,
                   Mandatory)]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ParameterSetName = 'dispose',
                   Mandatory)]
        [switch]
        $Dispose,

        [Parameter(ParameterSetName = 'scriptblock',
                   ValueFromPipeline,
                   Mandatory)]
        $Object,

        [Parameter(ParameterSetName = 'dispose',
                   ValueFromPipeline,
                   Mandatory)]
        [System.IDisposable]
        $DisposableObject
    )
    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'dispose' {
                try
                {
                    $DisposableObject
                }
                finally
                {
                    $DisposableObject.Dispose()
                }
            }
            'scriptblock' {
                try
                {
                    $Object
                }
                finally
                {
                    ,$Object | % $ScriptBlock
                }
            }
        }
    }
}

#####################
#region Save-WebFile
#####################

Add-Type -AssemblyName System.Net.Http.WebRequest
Add-Type -ReferencedAssemblies 'Microsoft.CSharp.dll' -TypeDefinition @'
using System;
using System.Threading;
using System.Management.Automation;
using System.Collections.ObjectModel;
using System.Collections.Generic;
using System.Management.Automation.Runspaces;

using System.Security.Cryptography.X509Certificates;
using System.Net.Security;

public class ScriptBlockInvoker
{
    public ScriptBlock ScriptBlock { get; private set; }
    public Dictionary<string, ScriptBlock> FunctionsToDefine { get; private set; }
    public List<PSVariable> VariablesToDefine { get; private set; }
    public object[] Args { get; private set; }

    Collection<PSObject> _ReturnValue;
    public Collection<PSObject> ReturnValue {
        get
        {
            if (!IsComplete)
            {
                throw new System.InvalidOperationException("Cannot access ReturnValue until Invoke() completes.");
            }
            return _ReturnValue;
        }
        private set { _ReturnValue = value; }
    }
    public bool IsComplete { get; private set; }
    public bool IsRunning { get; private set; }

    public void Init()
    {
        IsComplete = false;
        IsRunning = false;
    }

    public ScriptBlockInvoker(ScriptBlock scriptBlock)
    {
        Init();
        ScriptBlock = scriptBlock;
        VariablesToDefine = new List<PSVariable>();
        FunctionsToDefine = new Dictionary<string, ScriptBlock>();
    }

    public ScriptBlockInvoker(
        ScriptBlock scriptBlock,
        Dictionary<string, ScriptBlock> functionsToDefine,
        List<PSVariable> variablesToDefine,
        object[] args
    ) : this(scriptBlock)
    {
        FunctionsToDefine = functionsToDefine;
        VariablesToDefine = variablesToDefine;
        Args = args;
    }

    public void Invoke()
    {
        IsComplete = false;
        ReturnValue = null;
        IsRunning = true;
        if (Runspace.DefaultRunspace == null)
        {
            // Console.WriteLine("No default runspace.  Creating one.");
            Runspace.DefaultRunspace = RunspaceFactory.CreateRunspace();
        }
        ReturnValue = ScriptBlock.InvokeWithContext(
            FunctionsToDefine,
            VariablesToDefine,
            Args
        );
        IsComplete = true;
        IsRunning = false;
    }

    public Collection<PSObject> InvokeReturn()
    {
        Invoke();
        return ReturnValue;
    }

    public Func<Collection<PSObject>> InvokeFuncReturn
    {
        get { return InvokeReturn; }
    }

    public Action InvokeAction
    {
        get { return Invoke; }
    }

    public ThreadStart InvokeThreadStart
    {
        get { return Invoke; }
    }
}

public class CertificateValidator : ScriptBlockInvoker
{
    public CertificateValidator(ScriptBlock sb) : base(sb) { }

    public CertificateValidator(
        ScriptBlock scriptBlock,
        Dictionary<string, ScriptBlock> functionsToDefine,
        List<PSVariable> variablesToDefine,
        object[] args
    ) : base(scriptBlock,functionsToDefine,variablesToDefine,args)
    {}

    public bool CertValidationCallback(
        object sender,
        X509Certificate certificate,
        X509Chain chain,
        SslPolicyErrors sslPolicyErrors)
    {
        PSObject args = new PSObject();

        args.Members.Add(new PSNoteProperty("sender", sender));
        args.Members.Add(new PSNoteProperty("certificate", certificate));
        args.Members.Add(new PSNoteProperty("chain", chain));
        args.Members.Add(new PSNoteProperty("sslPolicyErrors", sslPolicyErrors));

        VariablesToDefine.Add(new PSVariable("_", args));

        Invoke();

        if ( ReturnValue.Count == 0)
        {
            return false;
        }

        foreach (var item in ReturnValue)
        {
            dynamic d = item.BaseObject;
            if (!d)
            {
                return false;
            }
        }
        return true;
    }

    public RemoteCertificateValidationCallback Delegate
    {
        get { return CertValidationCallback; }
    }
}
'@

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
            [System.Net.Http.WebRequestHandler]::new() | Afterward -Dispose |
                % {
                    $_.ServerCertificateValidationCallback = $CertificateValidationCallback
                    [System.Net.Http.HttpClient]::new($_)
                }
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
            New-FileStream Create | Afterward -Dispose |
            % {
                $CertificateValidator | 
                    New-CertificateValidationCallback |
                    New-HttpClient | Afterward -Dispose |
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
        $chainPolicy = @{}
        {
            foreach ( $propertyName in @(
                'RevocationMode'
                'RevocationFlag'
                'UrlRetrievalTimeout'
                'VerificationFlags'
            ))
            {
                $chainPolicy.$propertyName = $_.chain.ChainPolicy.$propertyName
            }

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
            New-HttpClient | Afterward -Dispose |
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
        
        $output = [pscustomobject]@{
            certificate = $streams.certificate | Deserialize ([X509Certificate])
            sslPolicyErrors = $streams.sslPolicyErrors | 
                                                 Deserialize ([System.Net.Security.SslPolicyErrors])
            chainPolicy = [pscustomobject]$chainPolicy
        }

        $propertyNames | % { $streams.$_.Dispose() }

        $output
    }
}

#endregion

##########################
#region Import-WebModule
##########################

$defaultManifestFileFilter = '*.psd1'
        
function Find-WebModuleSource
{
    param
    (
        [Parameter(ValueFromPipeline,
                    Mandatory)]
        [Microsoft.PowerShell.Commands.ModuleSpecification]
        $ModuleSpec,

        [Parameter(Position = 1,
                    Mandatory)]
        [hashtable]
        $SourceLookup
    )
    process
    {
        $match = $SourceLookup.Keys |
            ? {
                $lookupSpec = [Microsoft.PowerShell.Commands.ModuleSpecification]$_
                if ($lookupSpec.Name -eq $ModuleSpec.Name)
                {
                    if ( $ModuleSpec.Version )
                    {
                        $lookupSpec.Version -eq $ModuleSpec.Version
                    }
                    else
                    {
                        $true
                    }
                }
            }
        $count = $match | measure | % Count
        if ( $count -gt 1 )
        {
            throw "Found more than one match for module specification $ModuleSpec in SourceLookup."
        }
        if ( $count -lt 1 )
        {
            throw "Did not find a match module specification $ModuleSpec in SourceLookup."
        }
        $entry = $SourceLookup.$match
        Write-Verbose "Found source entry $entry for module $ModuleSpec."
        try
        {
            $entry
        }
        catch
        {
            throw [System.Exception]::new(
                "Module Spec: $ModuleSpec",
                $_.Exception
            )
        }
    }
}

function ConvertTo-WebModuleSourceArgs
{
    param
    (
        [Parameter(ParameterSetName = 'uri',
                    ValueFromPipeline,
                    Mandatory)]
        [uri]
        $Uri,

        [Parameter(ParameterSetName = 'hashtable',
                    ValueFromPipeline,
                    Mandatory)]
        [hashtable]
        $Hashtable
    )
    process
    {
        if ($PSCmdlet.ParameterSetName -eq 'uri')
        {
            return [pscustomobject]@{
                Uri=$Uri
                ManifestFileFilter = $defaultManifestFileFilter
            }
        }
        if ( -not $Hashtable.Uri )
        {
            throw "Hashtable does not contain entry for Uri"
        }
        if ( -not $Hashtable.Manifest -and
                -not $Hashtable.ManifestFile -and
                -not $Hashtable.ManifestFileFilter )
        {
            $Hashtable.ManifestFileFilter = $defaultManifestFileFilter
        }
        [pscustomobject]$Hashtable
    }
}

function Assert-Https
{
    param
    (
        [Parameter(ValueFromPipeline,
                    ValueFromPipelineByPropertyName,
                    Mandatory)]
        [uri]
        $Uri
    )
    process
    {
        if ($Uri.Scheme -ne 'https')
        {
            throw "Uri $Uri is not https"
        }
        $Uri
    }
}

function Save-WebModule
{
    param
    (
        [Parameter(ValueFromPipeline,
                    Mandatory)]
        [Uri]
        $Uri
    )
    process
    {
        $archivePath = [System.IO.Path]::GetTempPath()+[guid]::NewGuid().Guid+'.zip'
        Write-Verbose "Downloading $Uri to $archivePath..."
        $Uri | Save-WebFile $archivePath
        Write-Verbose 'Complete.'
        try
        {
            Get-Item $archivePath -ErrorAction Stop
        }
        catch
        {
            throw [System.Exception]::new(
                ("Uri: $Uri",
                    "Archive Path: $archivePath" -join [System.Environment]::NewLine),
                $_.Exception
            )
        }
    }
}

function Expand-WebModule
{
    param
    (
        [Parameter(ValueFromPipelineByPropertyName,
                    Mandatory)]
        [string]
        [Alias('FullName')]
        $Path
    )
    process
    {
        $destPath = [System.IO.Path]::GetTempPath()+[guid]::NewGuid().Guid
        Write-Verbose "Expanding archive $Path to $destPath..."
        $Path | Expand-Archive -Dest $destPath -ErrorAction Stop
        Write-Verbose 'Complete.'
        try
        {
            Get-Item $destPath -ErrorAction Stop
        }
        catch
        {
            throw [System.Exception]::new(
                ("Source path (Path): $ $Path",
                    "Dest path: $destPath" -join [System.Environment]::NewLine),
                $_.Exception
            )
        }
    }
}

function Find-ManifestFile
{
    param
    (
        [Parameter(Position = 1,
                    Mandatory)]
        [string]
        $Path,

        [Parameter(ValueFromPipelineByPropertyName,
                    Mandatory)]
        [Alias('Manifest')]
        [Alias('ManifestFile')]
        [Alias('ManifestFileFilter')]
        $Filter
    )
    process
    {
        $manifestFile = $Path | Get-ChildItem -Filter $Filter -Recurse -File
        $count = $manifestFile | measure | % Count
        if ( $count -gt 1 )
        {
            throw "Found more than one manifest file matched filter $Filter in the folder tree rooted at $Path : $($manifestFile.Name)"
        }
        if ( $count -lt 1 )
        {
            throw "Did not find a manifest file matching filter $Filter the folder tree rooted at $Path."
        }
        Write-Verbose "Found manifest file $Path."
        try
        {
            $manifestFile
        }
        catch
        {
            throw [System.Exception]::new(
                "Manifest Path: $($manifest.FullName)",
                $_.Exception
            )
        }
    }
}

function Get-RequiredModule
{
    param
    (
        [Parameter(ValueFromPipelineByPropertyName,
                    Mandatory)]
        [string]
        [Alias('FullName')]
        $Path
    )
    process
    {
        if ( $Path -notmatch '\.psd1$' )
        {
            throw "$Path does not have the .psd1 extension."
        }
        Write-Verbose "Retrieving contents of manifest file $Path."
        $contents = Import-PowerShellDataFile $Path -ErrorAction Stop

        foreach ( $requiredModule in $contents.RequiredModules )
        {
            $moduleSpec = [Microsoft.PowerShell.Commands.ModuleSpecification]$requiredModule
            Write-Verbose "Found required module $moduleSpec."
            try
            {
                $moduleSpec
            }
            catch
            {
                throw [System.Exception]::new(
                    "Required Module: $moduleSpec",
                    $_.Exception
                )
            }
        }
    }
}


function Import-WebModule
{
    <#
	.SYNOPSIS
	Imports a module from the web.

	.DESCRIPTION
	Import-WebModule downloads and imports a module and, optionally, the required modules mentioned in the module's manifest.  Import-WebModule works with a module if it meets the following criteria:
	 - has a module manifest
	 - is otherwise a well-formed PowerShell module
	 - is compressed into a single archive file with the .zip extension
	
	If Import-WebModule encounters a module that requires another module and SourceLookup is provided, Import-WebModule recursively downloads and imports the required modules.
	
	Import-WebModule downloads and expands modules to temporary locations.  Import-WebModule deletes the archives immediately after download.  Import-WebModule attempts to delete the files of the expanded module immediately after import but will silently leave them behind if that is not possible.  This can occur, for example, when the module contains an assembly that becomes locked when the module is loaded.
	
	.PARAMETER Uri
	The Uri from which to download the module.
	
	.PARAMETER ModuleSpec
	The module specification used to select the Uri from SourceLookup.
    
	.PARAMETER SourceLookup
	A hashtable used by Import-WebModule to lookup the Uri and ManifestFileFilter for a module.
	
	I must be possible to convert each key of SourceLookup to ModuleSpec.

	Values of SourceLookup must either be convertible to Uri or a hashtable containing two entries: Uri and ManifestFileFilter.  When importing a module that requires other modules, SourceLookup should include a key value pair for each module that is required.

    .PARAMETER ManifestFileFilter
	A filter passed by Import-WebModule to Get-ChildItem to select the manifest file for the module.

    .PARAMETER PassThru
    Returns the object output by the calls to Import-Module -PassThru. By default, this cmdlet does not generate any output.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Uri')]
    param
    (
        [Parameter(ParameterSetName = 'hashtable',
                   ValueFromPipeline,
                   Mandatory)]
        [Microsoft.PowerShell.Commands.ModuleSpecification]
        $ModuleSpec,

        [Parameter(ParameterSetName = 'hashtable',
                   Position = 1,
                   Mandatory)]
        [hashtable]
        $SourceLookup,

        [Parameter(ParameterSetName = 'Uri',
                   Position = 1,
                   Mandatory)]
        [Uri]
        $Uri,

        [Parameter(ParameterSetName = 'Uri',
                   Position = 2)]
        [string]
        $ManifestFileFilter = '*.psd1',

        [switch]
        $PassThru
    )
    process
    {
        if ( $PSCmdlet.ParameterSetName -eq 'Uri' )
        {
            'nameless' | Import-WebModule @{
                nameless = @{
                    Uri = $Uri
                    ManifestFileFilter = $ManifestFileFilter
                }
            } -PassThru:$PassThru
            return
        }
        $arguments = $ModuleSpec | 
            Find-WebModuleSource $SourceLookup |
            ConvertTo-WebModuleSourceArgs
                        
        $arguments |
            Assert-Https |
            Save-WebModule | Afterward {
                Write-Verbose "Removing downloaded file at $_"
                $_ | Remove-Item
            } |
            Expand-WebModule | Afterward {
                Write-Verbose "Attempting to remove module files at $_"
                $_ | Remove-Item -Recurse -ErrorAction SilentlyContinue
            } |
            % {
                $arguments |
                    Find-ManifestFile $_.FullName |
                    % {
                        $_ |
                            ? { $PSCmdlet.ParameterSetName -eq 'hashtable' } |
                            Get-RequiredModule |
                            % { $_ | Import-WebModule $SourceLookup -PassThru:$PassThru }
                        $_
                    } |
                    % FullName |
                    % { Write-Verbose "Importing module $_"; $_ } |
                    Import-Module -Global -PassThru:$PassThru -ErrorAction Stop
            }
    }
}

#endregion

Export-ModuleMember Import-WebModule,Save-WebFile,Get-ValidationObject