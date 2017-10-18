
#Requires -Version 5

################
#region utility
################

function Get-7d4176b6 { 'Get-7d4176b6' }

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
#endregion

########################
#region metaprogramming
########################

function Get-ParameterAst
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 1)]
        [string]
        $ParameterName,

        [Parameter(Mandatory = $true,
                   ValueFromPipeline = $true)]
        [System.Management.Automation.FunctionInfo]
        $FunctionInfo
    )
    process
    {
        $parameters = $FunctionInfo.ScriptBlock.Ast.Body.ParamBlock.Parameters
        if ( -not $ParameterName )
        {
            return $parameters
        }
        $parameters.Where({$_.Name.VariablePath.UserPath -eq $ParameterName})
    }
}

function Get-ParameterMetaData
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 1)]
        [string]
        $ParameterName,

        [Parameter(Mandatory = $true,
                   ValueFromPipeline = $true)]
        [System.Management.Automation.CommandInfo]
        $FunctionInfo
    )
    process
    {
        if ( $null -eq $FunctionInfo.Parameters )
        {
            return
        }
        if ( -not $ParameterName )
        {
            return $FunctionInfo.Parameters.get_Values()
        }
        if ( $ParameterName -notin $FunctionInfo.Parameters.get_Keys() )
        {
            return
        }
        $FunctionInfo.Parameters.get_Item($ParameterName)
    }
}

function Get-ParameterText
{
    param
    (
        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [System.Management.Automation.Language.ParameterAst]
        $Parameter
    )
    process
    {
        $Parameter.Extent.Text
    }
}
function Get-ParamblockText
{
    [CmdletBinding(DefaultParameterSetName = 'FunctionInfo')]
    param
    (
        [Parameter(ParameterSetName = 'CmdletInfo',
                   ValueFromPipeline,
                   Mandatory)]
        [System.Management.Automation.CmdletInfo]
        $CmdletInfo,

        [Parameter(ParameterSetName = 'FunctionInfo',
                   ValueFromPipeline,
                   Mandatory)]
        [System.Management.Automation.FunctionInfo]
        $FunctionInfo
    )
    process
    {
        if ( $PSCmdlet.ParameterSetName -eq 'FunctionInfo' )
        {
            return ($FunctionInfo | Get-ParameterAst | Get-ParameterText) -join ",`r`n"
        }

        [System.Management.Automation.ProxyCommand]::GetParamBlock(
            [System.Management.Automation.CommandMetadata]::new($CmdletInfo)
        )
    }
}

function Get-CmdletBindingAttributeText
{
    param
    (
        [Parameter(ValueFromPipeline,
                   Mandatory)]
        [System.Management.Automation.CommandInfo]
        $CommandInfo
    )
    process
    {
        [System.Management.Automation.ProxyCommand]::GetCmdletBindingAttribute(
            [System.Management.Automation.CommandMetadata]::new($CommandInfo)
        )
    }
}

function New-Tester
{
    param
    (
        [parameter(Mandatory,
                   ValueFromPipeline)]
        [System.Management.Automation.CommandInfo]
        $Getter,

        [Parameter(Position=1)]
        [scriptblock]
        $EqualityTester = {$_.Actual -eq $_.Expected},

        [string]
        $CommandName,

        [switch]
        $NoValue
    )
    process
    {
        $testerName = @{
            $false = "Test-$($Getter.Noun)"
            $true  = $CommandName
        }.($PSBoundParameters.ContainsKey('CommandName'))

        $getterParamNamesLiteral = ( $Getter | Get-ParameterMetaData | % { "'$($_.Name)'" }) -join ','

        $valueParamsText = @{
            $true = ''
            $false = '[Parameter(Position = 100)]$Value'
        }.([bool]$NoValue)

        $paramsText = (($Getter | Get-ParamblockText),$valueParamsText | ? {$_} ) -join ','

        @"
            function $testerName
            {
                $($Getter | Get-CmdletBindingAttributeText)
                param
                (
                    $paramsText
                )
                process
                {
                    `$splat = @{}
                    $getterParamNamesLiteral |
                        ? { `$PSBoundParameters.ContainsKey(`$_) } |
                        % { `$splat.`$_ = `$PSBoundParameters.get_Item(`$_) }

                    if ( `$PSBoundParameters.ContainsKey('Value') )
                    {
                        `$values = [pscustomobject]@{
                            Actual = $($Getter.Name) @splat
                            Expected = `$Value
                        }

                        return `$values | % {$EqualityTester}
                    }
                    return [bool](($($Getter.Name) @splat) -ne `$null)
                }
            }
"@
    }
}

function New-Asserter
{
    param
    (
        [parameter(Mandatory,
                   ValueFromPipeline)]
        [System.Management.Automation.CommandInfo]
        $Tester,

        [Parameter(ParameterSetName = 'string',
                   Mandatory,
                   Position = 1)]
        [string]
        $Message,

        [Parameter(ParameterSetName = 'scriptblock',
                   Mandatory,
                   Position = 1)]
        [scriptblock]
        $Scriptblock
    )
    process
    {
        $testerParamNamesLiteral = ( $Tester | Get-ParameterMetaData | % { "'$($_.Name)'" }) -join ','

        @"
            function Assert-$($Tester.Noun)
            {
                $($Tester | Get-CmdletBindingAttributeText)
                param
                (
                    $($Tester | Get-ParamblockText)
                )
                process
                {
                    `$splat = @{}
                    $testerParamNamesLiteral |
                        ? { `$PSBoundParameters.ContainsKey(`$_) } |
                        % { `$splat.`$_ = `$PSBoundParameters.get_Item(`$_) }

                    if ( $($Tester.Name) @splat )
                    {
                        return
                    }
                    $(@{
                        string = "throw `"$Message`""
                        scriptblock = "throw [string](& {$Scriptblock})"
                    }.($PSCmdlet.ParameterSetName))
                }
            }
"@
    }
}


#endregion

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
using System.Collections;
using System.Management.Automation.Runspaces;
using Microsoft.PowerShell.Commands;
using System.Security.Cryptography.X509Certificates;
using System.Net.Security;

public class ScriptBlockInvoker
{
    public ScriptBlock ScriptBlock { get; protected set; }
    public List<FunctionInfo> FunctionsToDefine { get; protected set; }
    public List<PSVariable> VariablesToDefine { get; protected set; }
    public List<Object> ArgumentList { get; protected set; }
    public Dictionary<string, object> NamedParameters { get; protected set; }
    public List<ModuleSpecification> ModulesToImport { get; protected set; }

    Collection<PSObject> _ReturnValue;
    public Collection<PSObject> ReturnValue
    {
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

    public ScriptBlockInvoker(
        ScriptBlock scriptBlock,
        List<FunctionInfo> functionsToDefine = null,
        List<PSVariable> variablesToDefine = null,
        List<Object> argumentList = null,
        Hashtable namedParameters = null,
        List<ModuleSpecification> modulesToImport = null
    )
    {
        IsComplete = false;
        IsRunning = false;
        ScriptBlock = scriptBlock;

        if (functionsToDefine != null)
        {
            FunctionsToDefine = functionsToDefine;
        }
        else
        {
            FunctionsToDefine = new List<FunctionInfo>();
        }

        if (variablesToDefine != null)
        {
            VariablesToDefine = variablesToDefine;
        }
        else
        {
            VariablesToDefine = new List<PSVariable>();
        }

        if (argumentList != null)
        {
            ArgumentList = argumentList;
        }
        else
        {
            ArgumentList = new List<Object>();
        }

        NamedParameters = new Dictionary<string, object>();
        if (namedParameters != null)
        {
            foreach (string key in namedParameters.Keys)
            {
                NamedParameters.Add(key, namedParameters[key]);
            }
        }

        if (modulesToImport != null)
        {
            ModulesToImport = modulesToImport;
        }
        else
        {
            ModulesToImport = new List<ModuleSpecification>();
        }
    }

    public void Invoke()
    {
        IsComplete = false;
        ReturnValue = null;
        IsRunning = true;

        var iss = InitialSessionState.CreateDefault();

        foreach (var variable in VariablesToDefine)
        {
            iss.Variables.Add(new SessionStateVariableEntry(
                variable.Name,
                variable.Value,
                variable.Description,
                variable.Options,
                variable.Attributes
            ));
        }

        foreach (var function in FunctionsToDefine)
        {
            iss.Commands.Add(new SessionStateFunctionEntry(
                function.Name,
                function.Definition,
                function.Options,
                function.HelpFile
            ));
        }

        iss.ImportPSModule(ModulesToImport);

        using (var rs = RunspaceFactory.CreateRunspace(iss))
        using (var ps = PowerShell.Create())
        {
            ps.Runspace = rs;
            rs.Open();
            ps.AddScript(ScriptBlock.ToString());

            foreach (var argument in ArgumentList)
            {
                ps.AddArgument(argument);
            }

            ps.AddParameters(NamedParameters);

            ReturnValue = ps.Invoke();
        }
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
    public CertificateValidator(
        ScriptBlock scriptBlock,
        List<FunctionInfo> functionsToDefine = null,
        List<PSVariable> variablesToDefine = null,
        List<object> argumentList = null,
        Hashtable namedParameters = null,
        List<ModuleSpecification> modulesToImport = null
    ) : base(scriptBlock,functionsToDefine,null,argumentList,namedParameters,modulesToImport)
    {
        VariablesToDefine = variablesToDefine;

        if (VariablesToDefine == null)
        {
            VariablesToDefine = new List<PSVariable>();
        }

        if (VariablesToDefine.Find(v => v.Name == "ErrorActionPreference")==null)
        {
            VariablesToDefine.Add(new PSVariable("ErrorActionPreference", ActionPreference.Stop));
        }
    }

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
            if (d.GetType() != typeof(bool))
            {
                return false;
            }
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
        [System.Management.Automation.FunctionInfo[]]
        $FunctionsToDefine,

        [psvariable[]]
        $VariablesToDefine,

        [System.Object[]]
        $ArgumentList,

        [hashtable]
        $NamedParameters,

        [Microsoft.PowerShell.Commands.ModuleSpecification[]]
        $ModulesToImport,

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
            [CertificateValidator]::new(
                $ScriptBlock,
                $FunctionsToDefine,
                $VariablesToDefine,
                $ArgumentList,
                $NamedParameters,
                $ModulesToImport
            ).Delegate
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
        $h = @{
            propertyNames = @(
                'certificate'
                #'sender'  # this type is not serializable
                #'chain'   # "
                'sslPolicyErrors'
            )
            streams = @{}
            chainPolicy = @{}
        }
        {
            foreach ( $propertyName in @(
                'RevocationMode'
                'RevocationFlag'
                'UrlRetrievalTimeout'
                'VerificationFlags'
            ))
            {
                $h.chainPolicy.$propertyName = $_.chain.ChainPolicy.$propertyName
            }

            foreach ( $propertyName in $h.propertyNames )
            {
                $h.streams.$propertyName = [System.IO.MemoryStream]::new()
                [System.Runtime.Serialization.Formatters.Binary.BinaryFormatter]::new().Serialize(
                    $h.streams.$propertyName,
                    $_.$propertyName
                )
            }
        } |
            New-CertificateValidationCallback -VariablesToDefine (Get-Variable h) |
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
            certificate = $h.streams.certificate | Deserialize ([System.Security.Cryptography.X509Certificates.X509Certificate2])
            sslPolicyErrors = $h.streams.sslPolicyErrors | 
                                                 Deserialize ([System.Net.Security.SslPolicyErrors])
            chainPolicy = [pscustomobject]$h.chainPolicy
        }

        $h.propertyNames | % { $h.streams.$_.Dispose() }

        $output
    }
}

#endregion

######################################
#region Certificate Validation Monads
######################################

function New-X509Chain
{
    [OutputType([System.Security.Cryptography.X509Certificates.X509Chain])]
    param()
    try
    {
        [System.Security.Cryptography.X509Certificates.X509Chain]::new()
    }
    catch
    {
        throw $_.Exception
    }
}

function Set-X509ChainPolicy
{
    param
    (
        [Parameter(Position = 1,Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509ChainPolicy]
        $Policy,

        [Parameter(ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Chain]
        $Chain
    )
    process
    {
        try
        {
            $Chain.ChainPolicy = $Policy
        }
        catch
        {
            throw $_.Exception
        }
    }
}

function Update-X509Chain
{
    [OutputType([System.Security.Cryptography.X509Certificates.X509Chain])]
    param
    (
        [Parameter(Position = 1,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [Parameter(ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Chain]
        $Chain
    )
    process
    {
        try
        {
            $success = $Chain.Build($Certificate)
        }
        catch
        {
            throw $_.Exception
        }
        if ( -not $success )
        {
            throw "Failure updating x509 chain for certificate $Certificate"
        }
        $Chain
    }
}

function Get-X509Intermediate
{
    [OutputType([System.Security.Cryptography.X509Certificates.X509ChainElement])]
    param
    (
        [Parameter(ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509ChainElementCollection]
        $ChainElements
    )
    process
    {
        if ( $ChainElements.Count -lt 3 )
        {
            return
        }

        $elements = $ChainElements |
            Select -First ($ChainElements.Count-1) |
            Select -Last  ($ChainElements.Count-2)

        foreach ( $element in $elements )
        {
            try
            {
                $element
            }
            catch
            {
                throw [System.Exception]::new(
                    $element.Certificate,
                    $_.Exception
                )
            }
        }
    }
}

function Get-X509SignatureAlgorithm
{
    [OutputType([System.Security.Cryptography.Oid])]
    param
    (
        [Parameter(ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate
    )
    process
    {
        try
        {
            $Certificate.SignatureAlgorithm
        }
        catch
        {
            throw [System.Exception]::new(
                "signature algorithm $($Certificate.SignatureAlgorithm.Value) $($Certificate.SignatureAlgorithm.FriendlyName)",
                $_.Exception
            )
        }
    }
}

function Get-OidFriendlyName
{
    [OutputType([string])]
    param
    (
        [Parameter(ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [System.Security.Cryptography.Oid]
        $Oid
    )
    process
    {
        try
        {
            $Oid.FriendlyName
        }
        catch
        {
            throw [System.Exception]::new(
                "signature algorithm $($Oid.Value) $($Oid.FriendlyName)",
                $_.Exception
            )
        }
    }
}

Get-Command Get-OidFriendlyName |
    New-Tester -EqualityTester { $_.Actual -in $_.Expected } |
    Invoke-Expression

Get-Command Test-OidFriendlyName |
    New-Asserter 'Signature algorithm friendly name $($Oid.FriendlyName) is not in $($Value -join '', '').' |
    Invoke-Expression

function Test-OidFips180_4
{
    [OutputType([bool])]
    param
    (
        [Parameter(ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [System.Security.Cryptography.Oid]
        $Oid
    )
    process
    {
        # algorithms list per NIST FIPS PUB 180-4
        # OIDs per IETF RFC7427
        # CRYPT_ALGORITHM_IDENTIFIER structure per https://msdn.microsoft.com/en-us/library/windows/desktop/aa381133(v=vs.85).aspx

        # only OIDs found in all of FIPS 180-4, 
        # RFC7427, and CRYPT_ALGORITHM_IDENTIFIER
        # are included in this list

        $Oid.Value -in @(
            # OID                   # Algorithm Name
            '1.2.840.113549.1.1.5'  # SHA-1
                                    # SHA-224
            '1.2.840.113549.1.1.11' # SHA-256
            '1.2.840.113549.1.1.12' # SHA-384
            '1.2.840.113549.1.1.13' # SHA-512
                                    # SHA-512/224
                                    # SHA-512/256
        )
    }
}

function Test-OidSha1
{
    [OutputType([bool])]
    param
    (
        [Parameter(ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [System.Security.Cryptography.Oid]
        $Oid
    )
    process
    {
        # OID per IETF RFC7427
        $Oid.Value -eq '1.2.840.113549.1.1.5'
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

Export-ModuleMember Import-WebModule,Save-WebFile,Get-ValidationObject,*X509*,*Oid*,Get-7d4176b6