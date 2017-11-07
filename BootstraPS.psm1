
#Requires -Version 5
$ErrorActionPreference = 'Stop'

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

Add-Type @'
    using System.Collections;
    namespace Bootstraps {
    namespace Metaprogramming {
        public class ParameterHashtable
        {
            public Hashtable Hashtable;
            public ParameterHashtable ( Hashtable h )
            {
                Hashtable = h;
            }
        }
    }}
'@ -ErrorAction Stop

function BeginFixPSBoundParameters
{
    param
    (
        [Parameter(Mandatory,ValueFromPipeline)]
        [System.Collections.Generic.IDictionary[System.String,System.Object]]
        $ThisPSBoundParameters
    )
    process
    {
        [Bootstraps.Metaprogramming.ParameterHashtable][hashtable]$ThisPSBoundParameters
    }
}

function ProcessFixPSBoundParameters
{
    param
    (
        [Parameter(Mandatory,ValueFromPipeline)]
        [Bootstraps.Metaprogramming.ParameterHashtable]
        $CommandLineParameters,

        [Parameter(Mandatory,Position=1)]
        [System.Collections.Generic.IDictionary[System.String,System.Object]]
        $ThisPSBoundParameters
    )
    process
    {
        $output = [hashtable]$ThisPSBoundParameters
        $keys = if ( $ThisPSBoundParameters.Count )
        {
            $ThisPSBoundParameters.get_Keys().Clone()
        }
        $keys |
            ? { $CommandLineParameters.Hashtable.get_Keys() -notcontains $_ } |
            % { [void]$ThisPSBoundParameters.Remove($_) }
        $output
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
            $ast = $FunctionInfo | Get-ParameterAst
            if ( -not $ast )
            {
                return ''
            }
            return ($ast | Get-ParameterText) -join ",`r`n"
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

        $getterParamNamesLiteral = if ( $Getter | Get-ParameterMetaData )
        {
            ( $Getter | Get-ParameterMetaData | % { "'$($_.Name)'" }) -join ','
        }
        else
        {
            'Out-Null'
        }

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
                begin
                {
                    `$CommandLineParameters = `$PSBoundParameters | BeginFixPSBoundParameters
                }
                process
                {
                    `$BoundParameters = `$CommandLineParameters | ProcessFixPSBoundParameters `$PSBoundParameters
                    `$splat = @{}
                    $getterParamNamesLiteral |
                        ? { `$BoundParameters.ContainsKey(`$_) } |
                        % { `$splat.`$_ = `$BoundParameters.get_Item(`$_) }

                    if ( `$BoundParameters.ContainsKey('Value') )
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
        $testerParamNamesLiteral = ($Tester | Get-ParameterMetaData | % { "'$($_.Name)'" }) -join ','

        @"
            function Assert-$($Tester.Noun)
            {
                $($Tester | Get-CmdletBindingAttributeText)
                param
                (
                    $($Tester | Get-ParamblockText)
                )
                begin
                {
                    `$CommandLineParameters = `$PSBoundParameters | BeginFixPSBoundParameters
                }
                process
                {
                    `$BoundParameters = `$CommandLineParameters | ProcessFixPSBoundParameters `$PSBoundParameters
                    `$splat = @{}
                    $testerParamNamesLiteral |
                        ? { `$BoundParameters.ContainsKey(`$_) } |
                        % { `$splat.`$_ = `$BoundParameters.get_Item(`$_) }

                    if ( $($Tester.Name) @splat )
                    {
                        return
                    }
                    $(@{
                        string = "throw `"$Message`""
                        scriptblock = "throw [string]({$Scriptblock}.InvokeWithContext(`$null,(Get-Variable BoundParameters),`$null))"
                    }.($PSCmdlet.ParameterSetName))
                }
            }
"@
    }
}

function Get-MemberField
{
    param
    (
        [Parameter(Position = 1)]
        [string]
        $Filter = '*',

        [Parameter(ValueFromPipeline = $true,
                   Mandatory = $true)]
        [System.Reflection.TypeInfo]
        $TypeInfo
    )
    process
    {
        foreach ( $field in (
            $TypeInfo.GetMembers() |
                ? { $_.MemberType -eq 'Field' } |
                ? { $_.Name -like $Filter }
        ))
        {
            try
            {
                $field
            }
            catch
            {
                throw [System.Exception]::new(
                    "Field $($field.Name) of type $($TypeInfo.Name)",
                    $_.Exception
                )
            }
        }
    }
}

function Get-FieldCustomAttribute
{
    param
    (
        [Parameter(Mandatory = $true,
                   Position = 1)]
        [string]
        $AttributeName,

        [Parameter(Mandatory = $true,
                   ValueFromPipeline = $true)]
        [System.Reflection.FieldInfo]
        $FieldInfo
    )
    process
    {
        $FieldInfo.CustomAttributes |
            ? {$_.AttributeType.Name -eq "$AttributeName`Attribute" }
    }
}

function Get-CustomAttributeArgument
{
    param
    (
        [Parameter(Mandatory)]
        [int]
        $Position,

        [switch]
        $ValueOnly,

        [Parameter(Mandatory = $true,
                   ValueFromPipeline = $true)]
        [System.Reflection.CustomAttributeData]
        $CustomAttributeData
    )
    process
    {
        $object = $CustomAttributeData.ConstructorArguments[$Position]
        if ($ValueOnly)
        {
            return $object.Value
        }
        return $object
    }
}

#endregion

#####################
#region common types
#####################

Add-Type @'
namespace BootstraPS
{
namespace Policy
{
    public enum Strictness
    {
        Normal,
        DangerousPermissive,
        Strict
    }
}}
'@ -ErrorAction Stop

#endregion

#####################
#region Save-WebFile
#####################

Add-Type -AssemblyName System.Net.Http.WebRequest -ErrorAction Stop
Add-Type -ReferencedAssemblies 'Microsoft.CSharp.dll' -ErrorAction Stop -TypeDefinition @'
using System;
using System.Threading;
using System.Management.Automation;
using System.Collections.ObjectModel;
using System.Collections.Generic;
using System.Collections;
using System.Management.Automation.Runspaces;
using Microsoft.PowerShell.Commands;
using System.Net.Security;
using System.Security.Authentication;
using System.Security.Cryptography.X509Certificates;

namespace BootstraPS
{
    namespace Concurrency
    {
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
            public bool SkipBuiltinSslPolicyCheck { get; private set; }

            public CertificateValidator(
                ScriptBlock scriptBlock,
                List<FunctionInfo> functionsToDefine = null,
                List<PSVariable> variablesToDefine = null,
                List<object> argumentList = null,
                Hashtable namedParameters = null,
                List<ModuleSpecification> modulesToImport = null,
                bool skipBuiltInSslPolicyCheck = false
            ) : base(scriptBlock, functionsToDefine, null, argumentList, namedParameters, modulesToImport)
            {
                VariablesToDefine = variablesToDefine;

                if (VariablesToDefine == null)
                {
                    VariablesToDefine = new List<PSVariable>();
                }

                if (VariablesToDefine.Find(v => v.Name == "ErrorActionPreference") == null)
                {
                    VariablesToDefine.Add(new PSVariable("ErrorActionPreference", ActionPreference.Stop));
                }

                SkipBuiltinSslPolicyCheck = skipBuiltInSslPolicyCheck;
            }

            public bool CertValidationCallback(
                object sender,
                X509Certificate certificate,
                X509Chain chain,
                SslPolicyErrors sslPolicyErrors)
            {
                if (!SkipBuiltinSslPolicyCheck && sslPolicyErrors != SslPolicyErrors.None)
                {
                    throw new AuthenticationException(String.Format(
                        "SSL Policy Error {0} for certificate {1}", sslPolicyErrors, certificate)
                    );
                }
                PSObject args = new PSObject();

                args.Members.Add(new PSNoteProperty("sender", sender));
                args.Members.Add(new PSNoteProperty("certificate", certificate));
                args.Members.Add(new PSNoteProperty("chain", chain));
                args.Members.Add(new PSNoteProperty("sslPolicyErrors", sslPolicyErrors));

                VariablesToDefine.Add(new PSVariable("_", args));

                Invoke();

                if (ReturnValue.Count == 0)
                {
                    return false;
                }

                foreach (var item in ReturnValue)
                {
                    if ( item == null )
                    {
                        return false;
                    }
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

            public RemoteCertificateValidationCallback Callback
            {
                get { return CertValidationCallback; }
            }
        }
    }
}
'@

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
    }
}

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

        [bool]
        $SkipBuiltInSslPolicyCheck,

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
            [BootstraPS.Concurrency.CertificateValidator]::new(
                $ScriptBlock,
                $FunctionsToDefine,
                $VariablesToDefine,
                $ArgumentList,
                $NamedParameters,
                $ModulesToImport,
                $SkipBuiltInSslPolicyCheck
            ).Callback
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
    <#
	.SYNOPSIS
	Save a file from the web.

	.DESCRIPTION
	Save-WebFile downloads a file from a server at Uri and saves it at Path.

	A scriptblock can optionally be passed to Save-WebFile's CertificateValidator parameter to validate an https server's certificate when Save-WebFile connects to the server.  CertificateValidator is invoked by the system callback with its own runspace and session state.  Because of this, the commands in the CertificateValidator scriptblock do not have access to the variables and modules at the Save-WebFile call site.

	BootstraPS exports a number of commands to help with validating certificates.  Those commands are available to the CertificateValidator scriptblock but other commands are not.

	The system might invoke CertificateValidator on a different thread from the thread that invoked Save-WebFile.

	The SecurityPolicy parameter can be provided to alter the permissiveness of Save-WebFile's TLS/SSL handshake according to the following table:

	    +---------------------+-------------+--------------------------------+
	    |                     | certificate |            allows              |
	    |  SecurityPolicy     | validation  +------+------------+------------+
	    |                     | performed   | http | protocols  | algorithms |
	    +---------------------+-------------+------+------------+------------+
	    | Normal (Default)    | SD, user    | no   | SD         | SD         |
	    | Strict              | SD, user    | no   | restricted | restricted |
	    | DangerousPermissive | user        | yes  | SD         | SD         |
	    +---------------------+-------------+------+------------+------------+

	    SD - system default
	    user - certificates are validated by the user-defined CertificateValidator parameter if it is provided
	    retricted - security policy that may be more restrictive than system defaults are imposed

	The exact nature of system default certificate validation performed and protocols and algorithms allowed may change from computer to computer and time to time.  Furthermore, the additional restrictions imposed by Save-WebFile may change from revision to revision of this implementation.

	.PARAMETER Uri
	The Uri from which to download the file.

	.PARAMETER Path
	The path to save the file.

	.PARAMETER SecurityPolicy
	The strictness of the policy Save-WebFile applies when establishing communication with the server.

	.PARAMETER CertificateValidator
	A scriptblock that is invoked by the system when connecting to Uri.  CertificateValidator's output tells the system whether the certificate is valid.  The system interprets the certificate to be valid if all outputs from CertificateValidator are $true.  If any output is $false, $null, or a non-boolean value or if there is no output, the system interprets the certificate to be invalid which causes Save-WebFile to throw an exception without downloading any file.  The automatic variable $_ is available in the scriptblock and has the properties sender, certificate, chain, and sslPolicyErrors whose values are the arguments passed by the system to System.Net.Security.RemoteCertificateValidationCallback.

    #>
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
        $Uri,

        [ValidateSet('Normal','Strict','DangerousPermissive')]
        [BootstraPS.Policy.Strictness]
        $SecurityPolicy
    )
    process
    {
        if ( $SecurityPolicy -eq [BootstraPS.Policy.Strictness]::DangerousPermissive )
        {
            $builtinCvCheck = @{ SkipBuiltInSslPolicyCheck = $true }
        }
        else
        {
            $Uri | Assert-Https
        }
        if ( $SecurityPolicy -eq [BootstraPS.Policy.Strictness]::Strict )
        {
            Assert-SchannelPolicy -Strict
            Assert-SpManagerPolicy -Strict
        }

        $Path |
            New-FileStream Create | Afterward -Dispose |
            % {
                $CertificateValidator |
                    New-CertificateValidationCallback -FunctionsToDefine (Get-CertValidationCommands) @builtinCvCheck |
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
#region Certificate Validation Commands
######################################

function Get-CertValidationCommands
{
    @(
        'Afterward'
        '*X509*'
        '*Oid*'
        '*FixPSBoundParameters'
        'Assert-SignatureAlgorithm'
    ) | Get-Command -Module BootstraPS
}

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

function New-X509ChainPolicy
{
    [OutputType([System.Security.Cryptography.X509Certificates.X509ChainPolicy])]
    param
    (
        [Parameter(Position = 1,
                   ValueFromPipelineByPropertyName)]
        [System.Security.Cryptography.OidCollection]
        $ApplicationPolicy,

        [Parameter(Position = 2,
                   ValueFromPipelineByPropertyName)]
        [System.Security.Cryptography.OidCollection]
        $CertificatePolicy,

        [Parameter(Position = 3,
                   ValueFromPipeline)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2Collection]
        $ExtraStore,

        [Parameter(ValueFromPipelineByPropertyName)]
        [System.Security.Cryptography.X509Certificates.X509RevocationFlag]
        $RevocationFlag,

        [Parameter(ValueFromPipelineByPropertyName)]
        [System.Security.Cryptography.X509Certificates.X509RevocationMode]
        $RevocationMode,

        [Parameter(ValueFromPipelineByPropertyName)]
        [timespan]
        $UrlRetrievalTimeout,

        [Parameter(ValueFromPipelineByPropertyName)]
        [System.Security.Cryptography.X509Certificates.X509VerificationFlags]
        $VerificationFlags,

        [Parameter(ValueFromPipelineByPropertyName)]
        [datetime]
        $VerificationTime
    )
    process
    {
        try
        {
            [System.Security.Cryptography.X509Certificates.X509ChainPolicy]$PSBoundParameters
        }
        catch
        {
            throw $_.Exception
        }
    }
}

function Set-X509ChainPolicy
{
    [OutputType([System.Security.Cryptography.X509Certificates.X509Chain])]
    param
    (
        [Parameter(Position = 1,Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509ChainPolicy]
        $Policy,

        [Parameter(ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Chain]
        $Chain,

        [switch]
        $PassThru
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
        if ( $PassThru )
        {
            $Chain
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
            Write-Error "Failure updating x509 chain for certificate $Certificate"
        }
        $Chain
    }
}

function Assert-X509ChainStatus
{
    param
    (
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ValueFromPipelineByPropertyName)]
        [System.Security.Cryptography.X509Certificates.X509ChainStatus[]]
        [AllowNull()]
        [AllowEmptyCollection()]
        $ChainStatus
    )
    process
    {
        if ( $ChainStatus.Count -gt 1 )
        {
            return $ChainStatus | Assert-X509ChainStatus
        }
        $item = $ChainStatus | select -First 1
        if ( $null -eq $item )
        {
            return
        }
        if ( $item.Status -ne [System.Security.Cryptography.X509Certificates.X509ChainStatusFlags]::NoError )
        {
            throw [System.Security.Authentication.AuthenticationException]::new(
                "ChainStatus is $($item.Status): $($item.StatusInformation)"
            )
        }
    }
}

Add-Type @'
namespace BootstraPS
{
namespace Certificate
{
    public enum ChainPosition
    {
        Root = 1,
        Intermediate,
        Server
    }
}}
'@ -ErrorAction Stop

function Get-X509ChainElement
{
    [OutputType([System.Security.Cryptography.X509Certificates.X509ChainElement])]
    param
    (
        [Parameter(ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509ChainElementCollection]
        $ChainElements,

        [BootstraPS.Certificate.ChainPosition[]]
        $Exclude
    )
    process
    {
        if ( $ChainElements.Count -lt 3 )
        {
            return
        }

        $elementsByPosition = @{
            [BootstraPS.Certificate.ChainPosition]::Root = {
                $ChainElements | Select -Last 1
            }
            [BootstraPS.Certificate.ChainPosition]::Intermediate = {
                $ChainElements |
                    Select -First ($ChainElements.Count-1) |
                    Select -Last  ($ChainElements.Count-2)
            }
            [BootstraPS.Certificate.ChainPosition]::Server = {
                $ChainElements | Select -First 1
            }
        }

        $elements = [BootstraPS.Certificate.ChainPosition].GetEnumValues() |
            ? { $_ -notin $Exclude } |
            % { & $elementsByPosition.$_ }

        foreach ( $element in $elements )
        {
            try
            {
                $element
            }
            catch
            {
                throw [System.Exception]::new(
                    "Intermediate Certificate: $($element.Certificate)",
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
    New-Tester -EqualityTester { $_.Actual -like $_.Expected } |
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

Get-Command Test-OidFips180_4 |
    New-Asserter 'Signature algorithm $($Oid.FriendlyName) ($($Oid.Value)) is not in the list of FIPS 180-4 algorithms.' |
    Invoke-Expression

function Test-OidNotSha1
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
        $Oid.Value -ne '1.2.840.113549.1.1.5'
    }
}

Get-Command Test-OidNotSha1 |
    New-Asserter 'Signature algorithm is $($Oid.FriendlyName) ($($Oid.Value)).' |
    Invoke-Expression

function Assert-X509ChainSignatureAlgorithm
{
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
        ,$ChainElements |
            Get-X509ChainElement -Exclude Root |
            Get-X509SignatureAlgorithm |
            % {
                $_ | Assert-OidFips180_4
                $_ | Assert-OidNotSha1
            }
    }
}

function Assert-SignatureAlgorithm
{
    param
    (
        [Parameter(ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [Parameter(Mandatory,
                   Position = 1)]
        [BootstraPS.Policy.Strictness]
        $Strictness
    )
    process
    {
        New-X509Chain | Afterward -Dispose |
            Update-X509Chain $Certificate -ErrorAction SilentlyContinue |
            Assert-X509ChainSignatureAlgorithm
    }
}

function Assert-X509NotRevoked
{
    param
    (
        [Parameter(Position = 1,
                   ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate
    )
    process
    {
        New-X509ChainPolicy -RevocationFlag EntireChain -RevocationMode Online |
            % {
                New-X509Chain | Afterward -Dispose |
                    Set-X509ChainPolicy $_ -PassThru |
                    Update-X509Chain $Certificate -ErrorAction SilentlyContinue |
                    Assert-X509ChainStatus
            }
    }
}

function Assert-X509Compliance
{
    param
    (
        [Parameter(ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [Parameter(Mandatory,
                   Position = 1)]
        [BootstraPS.Policy.Strictness]
        $Strictness
    )
    process
    {
        New-X509ChainPolicy -RevocationFlag EntireChain -RevocationMode Online |
            % {
                New-X509Chain | Afterward -Dispose |
                    Set-X509ChainPolicy $_ -PassThru |
                    Update-X509Chain $Certificate -ErrorAction SilentlyContinue |
                    % {
                        try
                        {
                            $_ | Assert-X509ChainStatus
                            $_ | Assert-X509ChainSignatureAlgorithm
                        }
                        catch
                        {
                            throw [System.Security.Authentication.AuthenticationException]::new(
                                "Certificate is invalid. $certificate",
                                $_.Exception
                            )
                        }
                    }
            }
    }
}

#endregion

#################
#region registry
#################

function Get-VolumeString
{
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory,ValueFromPipeline)]
        [string]
        $Path
    )
    process
    {
        if ( $Path -notmatch ':' )
        {
            return
        }
        try
        {
            $output = $Path.Split([System.IO.Path]::VolumeSeparatorChar)[0]
            $output
        }
        catch
        {
            throw [System.Exception]::new(
                "Path: $Path",
                $_.Exception
            )
        }
    }
}

Get-Command Get-VolumeString |
    New-Tester |
    Invoke-Expression

function Get-PathWithoutVolume
{
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory,ValueFromPipeline)]
        [string]
        $Path
    )
    process
    {
        try
        {
            & @{
                $false = { $Path }
                $true = {
                    $parts = $Path.Split([System.IO.Path]::VolumeSeparatorChar)
                    if ( $parts.Count -gt 2 )
                    {
                        throw 'Too many volume separators'
                    }
                    $parts[1]
                }
            }.($Path | Test-VolumeString) |
                % {$_.TrimStart('\/')} |
                ? {$_}
        }
        catch
        {
            throw [System.Exception]::new(
                "Path: $Path",
                $_.Exception
            )
        }
    }
}

function Get-Win32RegistryHive
{
    [OutputType([Microsoft.Win32.RegistryKey])]
    param
    (
        [Parameter(Mandatory,ValueFromPipeline)]
        [string]
        $Name
    )
    process
    {
        $hive = @{
            HKLM =               [Microsoft.Win32.Registry]::LocalMachine
            HKEY_LOCAL_MACHINE = [Microsoft.Win32.Registry]::LocalMachine
            HKCU =               [Microsoft.Win32.Registry]::CurrentUser
            HKEY_CURRENT_USER =  [Microsoft.Win32.Registry]::CurrentUser
            HKCR =               [Microsoft.Win32.Registry]::ClassesRoot
            HKEY_CLASSES_ROOT =  [Microsoft.Win32.Registry]::ClassesRoot
        }.$Name
        if ( $null -eq $hive )
        {
            throw "Unknown hive name: $Name"
        }
        try
        {
            $hive
        }
        catch
        {
            throw [System.Exception]::new(
                "Hive name: $Name",
                $_.Exception
            )
        }
    }
}

function ConvertTo-Win32RegistryPathArgs
{
    param
    (
        [Parameter(Mandatory,ValueFromPipeline)]
        $Path
    )
    process
    {
        [pscustomobject]@{
            Key =        $Path | Get-VolumeString | Get-Win32RegistryHive
            SubKeyPath = $Path | Get-PathWithoutVolume
        }
    }
}

function New-Win32RegistryKey
{
    [OutputType([Microsoft.Win32.RegistryKey])]
    param
    (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [Microsoft.Win32.RegistryKey]
        $Key,

        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [string]
        $SubKeyPath,

        [switch]
        $Writable
    )
    process
    {
        try
        {
            $Key.CreateSubKey($SubKeyPath,$Writable)
        }
        catch
        {
            throw [System.Exception]::new(
                ("Key: $($Key.Name)",
                 "SubKeyPath: $SubKeyPath",
                 "Writable: $Writable" -join [System.Environment]::NewLine),
                $_.Exception
            )
        }
    }
}

function Open-Win32RegistryKey
{
    [OutputType([Microsoft.Win32.RegistryKey])]
    param
    (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [Microsoft.Win32.RegistryKey]
        $Key,

        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [string]
        $SubKeyPath,

        [switch]
        $Writable
    )
    process
    {
        try
        {
            $Key.OpenSubKey($SubKeyPath,$Writable)
        }
        catch
        {
            throw [System.Exception]::new(
                ("Key: $($Key.Name)",
                 "SubKeyPath: $SubKeyPath",
                 "Writable: $Writable" -join [System.Environment]::NewLine),
                $_.Exception
            )
        }
    }
}

function Get-Win32RegistryKeyProperty
{
    param
    (
        [Parameter(Position = 1,
                   Mandatory)]
        [string]
        $PropertyName,

        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [Microsoft.Win32.RegistryKey]
        $Key
    )
    process
    {
        try
        {
            $Key.GetValue($PropertyName)
        }
        catch
        {
            throw [System.Exception]::new(
                ("Key: $($Key.Name)",
                 "PropertyName: $PropertyName" -join [System.Environment]::NewLine),
                $_.Exception
            )
        }
    }
}

function Set-Win32RegistryKeyProperty
{
    param
    (
        [Parameter(Position = 1,
                   Mandatory)]
        [string]
        $PropertyName,

        [Parameter(Position = 2,
                   Mandatory)]
        $Value,

        [Microsoft.Win32.RegistryValueKind]
        $Kind,

        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [Microsoft.Win32.RegistryKey]
        $Key
    )
    process
    {
        try
        {
            if ( $Kind )
            {
                $Key.SetValue($PropertyName,$Value,$Kind)
            }
            else
            {
                $Key.SetValue($PropertyName,$Value)
            }
        }
        catch
        {
            throw [System.Exception]::new(
                ("Key: $($Key.Name)",
                 "PropertyName: $PropertyName",
                 "Value: $Value",
                 "Kind: $Kind" -join [System.Environment]::NewLine),
                $_.Exception
            )
        }
    }
}

function Get-Win32RegistryKeyPropertyKind
{
    [OutputType([Microsoft.Win32.RegistryValueKind])]
    param
    (
        [Parameter(Position = 1,
                   Mandatory)]
        [string]
        $PropertyName,

        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [Microsoft.Win32.RegistryKey]
        $Key
    )
    process
    {
        try
        {
            try
            {
                $Key.GetValueKind($PropertyName)
            }
            catch [System.IO.IOException]
            {
                [Microsoft.Win32.RegistryValueKind]::Unknown
            }
        }
        catch
        {
            throw [System.Exception]::new(
                ("Key: $($Key.Name)",
                 "PropertyName: $PropertyName" -join [System.Environment]::NewLine),
                $_.Exception
            )
        }
    }
}

Add-Type -ErrorAction Stop -TypeDefinition @'
using Microsoft.Win32;
using System.Collections;

namespace BootstraPS
{
    namespace Registry
    {
        public class RegItemInfo
        {
            protected string _path;
            public string Path { get { return _path; } }
        }
        public class KeyInfo : RegItemInfo {}
        public class KeyPresentInfo : KeyInfo
        {
            public KeyPresentInfo(string path)
            {
                _path = path;
            }
        }
        public class KeyAbsentInfo : KeyInfo
        {
            public readonly bool Absent = true;

            public KeyAbsentInfo(string path)
            {
                _path = path;
            }
        }
        public class PropertyInfo : RegItemInfo
        {
            protected string _propertyName;
            public string PropertyName { get { return _propertyName; } }
        }
        public class PropertyAbsentInfo : PropertyInfo
        {
            public readonly bool Absent = true;

            public PropertyAbsentInfo(
                string path,
                string propertyName
            )
            {
                _path = path;
                _propertyName = propertyName;
            }
        }
        public class PropertyPresentInfo : PropertyInfo
        {
            public readonly object Value;
            public readonly RegistryValueKind Kind;

            public PropertyPresentInfo(
                string path,
                string propertyName,
                object value,
                RegistryValueKind kind
            )
            {
                _path = path;
                _propertyName = propertyName;
                Value = value;
                Kind = kind;
            }
        }
    }
}
'@

function Get-RegistryKey
{
    [OutputType([BootstraPS.Registry.KeyPresentInfo])]
    param
    (
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ValueFromPipelineByPropertyName)]
        [string]
        $Path
    )
    process
    {
        $Path |
            ConvertTo-Win32RegistryPathArgs |
            Open-Win32RegistryKey | ? {$_} | Afterward -Dispose |
            % { [BootstraPS.Registry.KeyPresentInfo]::new($Path) }
    }
}

Get-Command Get-RegistryKey |
    New-Tester -NoValue |
    Invoke-Expression

function Get-RegistryProperty
{
    [OutputType([BootstraPS.Registry.PropertyPresentInfo])]
    param
    (
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ValueFromPipelineByPropertyName)]
        [string]
        $Path,

        [Parameter(Position = 1,
                   Mandatory,
                   ValueFromPipelineByPropertyName)]
        [string]
        $PropertyName
    )
    process
    {
        $Path |
            ConvertTo-Win32RegistryPathArgs |
            Open-Win32RegistryKey | ?{$_} | Afterward -Dispose |
            % {
                $value = $_ | Get-Win32RegistryKeyProperty     $PropertyName
                $kind =  $_ | Get-Win32RegistryKeyPropertyKind $PropertyName
            }

        if ( $null -eq $value -and
             -not $kind)
        {
            return
        }

        [BootstraPS.Registry.PropertyPresentInfo]::new(
            $Path,
            $PropertyName,
            $value,
            $kind
        )
    }
}

Get-Command Get-RegistryProperty |
    New-Tester -EqualityTester { $_.Expected -eq $_.Actual.Value } |
    Invoke-Expression

function Get-RegistryKeyInfo
{
    [OutputType([BootstraPS.Registry.KeyInfo])]
    param
    (
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ValueFromPipelineByPropertyName)]
        [string]
        $Path
    )
    process
    {
        throw [System.NotImplementedException]::new(
            "Get-RegistryKeyInfo, Path: $Path"
        )
    }
}

function Get-RegistryPropertyInfo
{
    [OutputType([BootstraPS.Registry.PropertyInfo])]
    param
    (
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ValueFromPipelineByPropertyName)]
        [string]
        $Path,

        [Parameter(Position = 1,
                   Mandatory,
                   ValueFromPipelineByPropertyName)]
        [string]
        $PropertyName
    )
    process
    {
        $property = Get-RegistryProperty @PSBoundParameters
        if ( -not $property )
        {
            [BootstraPS.Registry.PropertyAbsentInfo]::new(
                $Path,
                $PropertyName
            )
        }
        $property
    }
}

function Set-RegistryKey
{
    param
    (
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ValueFromPipelineByPropertyName)]
        [string]
        $Path,

        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]
        $Absent
    )
    process
    {
        if ( $Absent )
        {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        }
        elseif ( -not ($Path | Test-RegistryKey) )
        {
            $Path |
                ConvertTo-Win32RegistryPathArgs |
                New-Win32RegistryKey | Afterward -Dispose |
                Out-Null
        }
    }
}

function Set-RegistryProperty
{
    [CmdletBinding(DefaultParameterSetName = 'present')]
    param
    (
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ValueFromPipelineByPropertyName)]
        [string]
        $Path,

        [Parameter(Position = 1,
                   Mandatory,
                   ValueFromPipelineByPropertyName)]
        [string]
        $PropertyName,

        [Parameter(ParameterSetName = 'present',
                   Position = 2,
                   ValueFromPipelineByPropertyName)]
        $Value,

        [Parameter(ParameterSetName = 'present',
                   ValueFromPipelineByPropertyName)]
        [Microsoft.Win32.RegistryValueKind]
        $Kind,

        [Parameter(ParameterSetName = 'absent',
                   Mandatory,
                   ValueFromPipelineByPropertyName)]
        [switch]
        $Absent
    )
    process
    {
        if ( $PSCmdlet.ParameterSetName -eq 'absent' )
        {
            Remove-ItemProperty -LiteralPath $Path -Name $PropertyName -ErrorAction Stop
        }
        else
        {
            $Path |
                % {
                    $_ | Set-RegistryKey
                    $_
                } |
                ConvertTo-Win32RegistryPathArgs |
                Open-Win32RegistryKey -Writable | Afterward -Dispose |
                Set-Win32RegistryKeyProperty $PropertyName $Value -Kind $Kind
        }
    }
}


#endregion

#################
#region schannel
#################

# https://technet.microsoft.com/en-us/library/dn786418(v=ws.11).aspx#BKMK_SchannelTR_CipherSuites
# https://support.microsoft.com/en-us/help/245030/how-to-restrict-the-use-of-certain-cryptographic-algorithms-and-protoc
# https://github.com/Crosse/SchannelGroupPolicy

Add-Type -ErrorAction Stop -TypeDefinition @'
namespace BootstraPS
{
namespace Schannel
{
    class KeyNameAttribute : System.Attribute
    {
        public KeyNameAttribute(string value)
        {
            Value = value;
        }

        public string Value
        {
            get { return Value; }
            private set { Value = value; }
        }
    }
    public enum Ciphers
    {
        [KeyName("NULL")]           NULL = 1,
        [KeyName("AES 128/128")]    AES_128_128,
        [KeyName("AES 256/256")]    AES_256_256,
        [KeyName("RC2 40/128")]     RC2_40_128,
        [KeyName("RC2 56/56")]      RC2_56_56,
        [KeyName("RC2 56/128")]     RC2_56_128,
        [KeyName("RC2 128/128")]    RC2_128_128,
        [KeyName("RC4 40/128")]     RC4_40_128,
        [KeyName("RC4 56/128")]     RC4_56_128,
        [KeyName("RC4 64/128")]     RC4_64_128,
        [KeyName("RC4 128/128")]    RC4_128_128,
        [KeyName("Triple DES 168")] TripleDES,
    }
    public enum Hashes
    {
        [KeyName("MD5")]    MD5 = 1,
        [KeyName("SHA")]    SHA1,
        [KeyName("SHA256")] SHA256,
        [KeyName("SHA384")] SHA384,
        [KeyName("SHA512")] SHA512,
    }
    public enum KeyExchangeAlgorithms
    {
        [KeyName("PKCS")] PKCS = 1,
        [KeyName("ECDH")] ECDH,
        [KeyName("Diffie-Hellman")] DH
    }
    public enum Protocols
    {
        [KeyName("Multi-Protocol Unified Hello")] MPUH = 1,
        [KeyName("PCT 1.0")] PCT_1_0,
        [KeyName("SSL 2.0")] SSL_2_0,
        [KeyName("SSL 3.0")] SSL_3_0,
        [KeyName("TLS 1.0")] TLS_1_0,
        [KeyName("TLS 1.1")] TLS_1_1,
        [KeyName("TLS 1.2")] TLS_1_2
    }
    public enum Role
    {
        [KeyName("Client")] Client = 1,
        [KeyName("Server")] Server
    }
    public enum EnableType
    {
        DisabledByDefault = 1,
        Enabled
    }
    public enum PropertyState
    {
        Absent,
        Clear,
        Set
    }
    public enum EnabledValues
    {
        Clear =                0x0,
        Set =   unchecked((int)0xFFFFFFFF)
    }
    public enum DisabledByDefaultValues
    {
        Clear = 0x0,
        Set =   0x00000001
    }
}
}
'@

function Get-SchannelKeyName
{
    [OutputType([string])]
    param
    (
        [Parameter(ValueFromPipeline,
                   Mandatory)]
        [System.Enum]
        $EnumValue
    )
    process
    {
        $ENumValue.GetType() |
            Get-MemberField $EnumValue |
            Get-FieldCustomAttribute KeyName |
            Get-CustomAttributeArgument -Position 0 -ValueOnly
    }
}

function Get-SchannelKeyPath
{
    param
    (
        [Parameter(ParameterSetName='Ciphers',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Ciphers]
        $Cipher,

        [Parameter(ParameterSetName='Hashes',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Hashes]
        $Hash,

        [Parameter(ParameterSetName='KeyExchangeAlgorithms',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.KeyExchangeAlgorithms]
        $KeyExchangeAlgorithm,

        [Parameter(ParameterSetName='Protocols',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Protocols]
        $Protocol,

        [Parameter(ParameterSetName='Protocols',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Role]
        $Role
    )
    process
    {
        $keyName = $Cipher,$Hash,$KeyExchangeAlgorithm,$Protocol |
            ? {$_} |
            Get-SchannelKeyName

        if ( $PSCmdlet.ParameterSetName -eq 'Protocols' )
        {
            "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$keyName\$Role"
            return
        }
        "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\$($PSCmdlet.ParameterSetName)\$keyName"
    }
}

function Get-SchannelRegistryEntry
{
    [OutputType([BootstraPS.Registry.PropertyInfo])]
    param
    (
        [Parameter(Position = 1,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.EnableType]
        $EnableType,

        [Parameter(ParameterSetName='Ciphers',
                   ValueFromPipelineByPropertyName,
                   ValueFromPipeline,
                   Mandatory)]
        [BootstraPS.Schannel.Ciphers]
        $Cipher,

        [Parameter(ParameterSetName='Hashes',
                   ValueFromPipelineByPropertyName,
                   ValueFromPipeline,
                   Mandatory)]
        [BootstraPS.Schannel.Hashes]
        $Hash,

        [Parameter(ParameterSetName='KeyExchangeAlgorithms',
                   ValueFromPipelineByPropertyName,
                   ValueFromPipeline,
                   Mandatory)]
        [BootstraPS.Schannel.KeyExchangeAlgorithms]
        $KeyExchangeAlgorithm,

        [Parameter(ParameterSetName='Protocols',
                   ValueFromPipelineByPropertyName,
                   ValueFromPipeline,
                   Mandatory)]
        [BootstraPS.Schannel.Protocols]
        $Protocol,

        [Parameter(ParameterSetName='Protocols',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Role]
        $Role
    )
    begin
    {
        $CommandLineParameters = $PSBoundParameters | BeginFixPSBoundParameters
    }
    process
    {
        $BoundParameters = $CommandLineParameters | ProcessFixPSBoundParameters $PSBoundParameters

        [pscustomobject]$BoundParameters |
            Get-SchannelKeyPath |
            Get-RegistryPropertyInfo $EnableType
    }
}

function Set-SchannelRegistryEntry
{
    param
    (
        [Parameter(Position = 1,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.EnableType]
        $EnableType,

        [Parameter(ParameterSetName='Ciphers',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Ciphers]
        $Cipher,

        [Parameter(ParameterSetName='Hashes',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Hashes]
        $Hash,

        [Parameter(ParameterSetName='KeyExchangeAlgorithms',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.KeyExchangeAlgorithms]
        $KeyExchangeAlgorithm,

        [Parameter(ParameterSetName='Protocols',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Protocols]
        $Protocol,

        [Parameter(ParameterSetName='Protocols',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Role]
        $Role
    )
    begin
    {
        $CommandLineParameters = $PSBoundParameters | BeginFixPSBoundParameters
    }
    process
    {
        $BoundParameters = $CommandLineParameters | ProcessFixPSBoundParameters $PSBoundParameters
        [pscustomobject]$BoundParameters |
            Get-SchannelKeyPath |
            Set-RegistryProperty $EnableType (@{
                [BootstraPS.Schannel.EnableType]::DisabledByDefault = [BootstraPS.Schannel.DisabledByDefaultValues]::Set
                [BootstraPS.Schannel.EnableType]::Enabled           = [BootstraPS.Schannel.EnabledValues]::Set
            }.$EnableType) -Kind DWord
    }
}

function Clear-SchannelRegistryEntry
{
    param
    (
        [Parameter(Position = 1,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.EnableType]
        $EnableType,

        [Parameter(ParameterSetName='Ciphers',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Ciphers]
        $Cipher,

        [Parameter(ParameterSetName='Hashes',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Hashes]
        $Hash,

        [Parameter(ParameterSetName='KeyExchangeAlgorithms',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.KeyExchangeAlgorithms]
        $KeyExchangeAlgorithm,

        [Parameter(ParameterSetName='Protocols',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Protocols]
        $Protocol,

        [Parameter(ParameterSetName='Protocols',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Role]
        $Role
    )
    begin
    {
        $CommandLineParameters = $PSBoundParameters | BeginFixPSBoundParameters
    }
    process
    {
        $BoundParameters = $CommandLineParameters | ProcessFixPSBoundParameters $PSBoundParameters
        [pscustomobject][hashtable]$BoundParameters |
            Get-SchannelKeyPath |
            Set-RegistryProperty $EnableType (@{
                [BootstraPS.Schannel.EnableType]::DisabledByDefault = [BootstraPS.Schannel.DisabledByDefaultValues]::Clear
                [BootstraPS.Schannel.EnableType]::Enabled           = [BootstraPS.Schannel.EnabledValues]::Clear
            }.$EnableType) -Kind DWord
    }
}

function Remove-SchannelRegistryEntry
{
    param
    (
        [Parameter(Position = 1,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.EnableType]
        $EnableType,

        [Parameter(ParameterSetName='Ciphers',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Ciphers]
        $Cipher,

        [Parameter(ParameterSetName='Hashes',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Hashes]
        $Hash,

        [Parameter(ParameterSetName='KeyExchangeAlgorithms',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.KeyExchangeAlgorithms]
        $KeyExchangeAlgorithm,

        [Parameter(ParameterSetName='Protocols',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Protocols]
        $Protocol,

        [Parameter(ParameterSetName='Protocols',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Role]
        $Role
    )
    begin
    {
        $CommandLineParameters = $PSBoundParameters | BeginFixPSBoundParameters
    }
    process
    {
        $BoundParameters = $CommandLineParameters | ProcessFixPSBoundParameters $PSBoundParameters
        [pscustomobject]$BoundParameters |
            Get-SchannelKeyPath |
            % { Remove-ItemProperty -LiteralPath $_ -Name $EnableType -ErrorAction Stop }
    }
}

function Test-SchannelRegistryEntry
{
    [OutputType([bool])]
    param
    (
        [Parameter(Position = 1,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.PropertyState]
        $ExpectedState,

        [Parameter(Position = 2,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.EnableType]
        $EnableType,

        [Parameter(ParameterSetName='Ciphers',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Ciphers]
        $Cipher,

        [Parameter(ParameterSetName='Hashes',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Hashes]
        $Hash,

        [Parameter(ParameterSetName='KeyExchangeAlgorithms',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.KeyExchangeAlgorithms]
        $KeyExchangeAlgorithm,

        [Parameter(ParameterSetName='Protocols',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Protocols]
        $Protocol,

        [Parameter(ParameterSetName='Protocols',
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [BootstraPS.Schannel.Role]
        $Role
    )
    begin
    {
        $CommandLineParameters = $PSBoundParameters | BeginFixPSBoundParameters
    }
    process
    {
        $BoundParameters = $CommandLineParameters | ProcessFixPSBoundParameters $PSBoundParameters
        $actual = [pscustomobject]$BoundParameters |
            Get-SchannelRegistryEntry

        # check for invalid registry value kind
        if ( -not $actual.Absent -and ($actual.Kind -ne [Microsoft.Win32.RegistryValueKind]::DWord) )
        {
            Write-Warning "The registry property $($actual.PropertyName) at $($actual.Path) is invalid kind $($actual.Kind)."
            return $false
        }

        # check for bogus values
        if ( $actual.Value -notin @(
            $null
            (@{
                [BootstraPS.Schannel.EnableType]::DisabledByDefault = [BootstraPS.Schannel.DisabledByDefaultValues]
                [BootstraPS.Schannel.EnableType]::Enabled           = [BootstraPS.Schannel.EnabledValues]
            }.$EnableType).GetEnumValues()
        ))
        {
            Write-Warning "The registry property $($actual.PropertyName) at $($actual.Path) has invalid value $($actual.Value)."
            return $false
        }

        # check for expected absent
        if ( $ExpectedState -eq [BootstraPS.Schannel.PropertyState]::Absent )
        {
            return [bool]$actual.Absent
        }

        # lookup the right enumeration and compare it with the actual value
        @{
            [BootstraPS.Schannel.EnableType]::DisabledByDefault = @{
                [BootstraPS.Schannel.PropertyState]::Clear = [BootstraPS.Schannel.DisabledByDefaultValues]::Clear
                [BootstraPS.Schannel.PropertyState]::Set =   [BootstraPS.Schannel.DisabledByDefaultValues]::Set
            }.$ExpectedState
            [BootstraPS.Schannel.EnableType]::Enabled = @{
                [BootstraPS.Schannel.PropertyState]::Clear = [BootstraPS.Schannel.EnabledValues]::Clear
                [BootstraPS.Schannel.PropertyState]::Set =   [BootstraPS.Schannel.EnabledValues]::Set
            }.$ExpectedState
        }.$EnableType -eq $actual.Value
    }
}

Get-Command Test-SchannelRegistryEntry |
    New-Asserter {
        $actual = [pscustomobject]$BoundParameters |
            Get-SchannelRegistryEntry
        "The registry property $($actual.PropertyName) at $($actual.Path) is not in the $ExpectedState state."
    } |
    Invoke-Expression

function Get-SchannelRegistryPolicy
{
    param
    (
        [Parameter(Mandatory)]
        [switch]
        $Strict
    )
    # this policy disables weak ciphers, hashes, and key exchange algorithms
    @(
        [BootstraPS.Schannel.Ciphers].GetEnumValues() |
            ? { $_ -match 'RC4' } |
            % { @{ Cipher = $_ } }

        [BootstraPS.Schannel.Hashes].GetEnumValues() |
            ? { $_ -match 'MD5' } |
            % { @{ Hash = $_ } }

        [BootstraPS.Schannel.KeyExchangeAlgorithms]::DH |
            % { @{ KeyExchangeAlgorithm = $_ } }
    ) |
        % {
            $_.EnableType = [BootstraPS.Schannel.EnableType]::Enabled
            $_.ExpectedState = [BootstraPS.Schannel.PropertyState]::Clear
            $_
        } |
        % {[pscustomobject]$_ }
}

function Set-SchannelRegistryPolicy
{
    param
    (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [BootstraPS.Schannel.PropertyState]
        $ExpectedState,

        [Parameter(ValueFromPipeline,Mandatory)]
        $InputObject
    )
    process
    {
        switch ($ExpectedState)
        {
            ([BootstraPS.Schannel.PropertyState]::Absent) {
                $InputObject | Remove-SchannelRegistryEntry
            }
            ([BootstraPS.Schannel.PropertyState]::Clear) {
                $InputObject | Clear-SchannelRegistryEntry
            }
            ([BootstraPS.Schannel.PropertyState]::Set) {
                $InputObject | Set-SchannelRegistryEntry
            }
        }
    }
}

function Assert-SchannelPolicy
{
    param
    (
        [Parameter(Mandatory)]
        [switch]
        $Strict
    )
    Get-SchannelRegistryPolicy @PSBoundParameters |
        Assert-SchannelRegistryEntry
}

function Set-SchannelPolicy
{
    param
    (
        [Parameter(Mandatory)]
        [switch]
        $Strict
    )
    Get-SchannelRegistryPolicy @PSBoundParameters |
        Set-SchannelRegistryPolicy
}

#endregion

#############################
#region ServicePointManager
#############################

function Get-SpManagerProtocol
{
    [System.Net.ServicePointManager]::SecurityProtocol
}

Get-Command Get-SpManagerProtocol |
    New-Tester {[bool]($_.Actual -band $_.Expected)} -CommandName Test-SpManagerProtocolEnabled |
    Invoke-Expression

Get-Command Get-SpManagerProtocol |
    New-Tester {-not ($_.Actual -band $_.Expected)} -CommandName Test-SpManagerProtocolDisabled |
    Invoke-Expression

Get-Command Test-SpManagerProtocolEnabled |
    New-Asserter '$Value is not set in [ServicePointManager]::SecurityProtocol.  Actual value is $(Get-SpManagerProtocol).' |
    Invoke-Expression

Get-Command Test-SpManagerProtocolDisabled |
    New-Asserter '$Value is set in [ServicePointManager]::SecurityProtocol.  Actual value is $(Get-SpManagerProtocol).' |
    Invoke-Expression

function Set-SpManagerProtocol
{
    param
    (
        [Parameter(ValueFromPipeline,Mandatory)]
        [System.Net.SecurityProtocolType]
        $SecurityProtocol
    )
    process
    {
        [System.Net.ServicePointManager]::SecurityProtocol = $SecurityProtocol
    }
}

function Disable-SpManagerProtocol
{
    param
    (
        [Parameter(ValueFromPipeline,Mandatory)]
        [System.Net.SecurityProtocolType]
        $SecurityProtocol
    )
    process
    {
        $old = [System.Net.ServicePointManager]::SecurityProtocol
        $new = (-bnot $SecurityProtocol) -band $old
        [System.Net.ServicePointManager]::SecurityProtocol = $new
    }
}

function Enable-SpManagerProtocol
{
    param
    (
        [Parameter(ValueFromPipeline,Mandatory)]
        [System.Net.SecurityProtocolType]
        $SecurityProtocol
    )
    process
    {
        $old = [System.Net.ServicePointManager]::SecurityProtocol
        $new = $SecurityProtocol -bor $old
        [System.Net.ServicePointManager]::SecurityProtocol = $new
    }
}

function Merge-SpManagerProtocol
{
    [OutputType([System.Net.SecurityProtocolType])]
    param
    (
        [Parameter(ValueFromPipeline,Mandatory)]
        [System.Nullable[System.Net.SecurityProtocolType]]
        $SecurityProtocol
    )
    process
    {
        $accumulator = $SecurityProtocol -bor $accumulator
    }
    end
    {
        $accumulator
    }
}

function Assert-SpManagerPolicy
{
    param
    (
        [Parameter(Mandatory)]
        [switch]
        $Strict
    )
    Assert-SpManagerProtocolDisabled ([System.Net.SecurityProtocolType]::Ssl3)
}

function Set-SpManagerPolicy
{
    param
    (
        [Parameter(Mandatory)]
        [switch]
        $Strict
    )
    Disable-SpManagerProtocol ([System.Net.SecurityProtocolType]::Ssl3)
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

function Save-WebModule
{
    param
    (
        [Parameter(ValueFromPipelineByPropertyName)]
        [scriptblock]
        $CertificateValidator,

        [Parameter(ValueFromPipelineByPropertyName)]
        [BootstraPS.Policy.Strictness]
        $SecurityPolicy,

        [Parameter(ValueFromPipelineByPropertyName,
                   ValueFromPipeline,
                   Mandatory)]
        [Uri]
        $Uri
    )
    process
    {
        $archivePath = [System.IO.Path]::GetTempPath()+[guid]::NewGuid().Guid+'.zip'
        Write-Verbose "Downloading $Uri to $archivePath..."
        Save-WebFile $archivePath @PSBoundParameters | Out-Null
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
	Import-WebModule downloads and imports a module and, optionally, the required modules mentioned in the module's manifest.  Import-WebModule works with modules that meet the following criteria:
	 - has a module manifest
	 - is otherwise a well-formed PowerShell module
	 - is compressed into a single archive file with the .zip extension

	If Import-WebModule encounters a module that requires another module and SourceLookup is provided, Import-WebModule looks for a source for the required module in SourceLookup and recursively downloads and imports the required modules.

	Import-WebModule downloads and expands modules to temporary locations.  Import-WebModule deletes the archives immediately after expansion.  Import-WebModule attempts to delete the files of the expanded module immediately after import but will silently leave them behind if that is not possible.  This can occur, for example, when the module contains an assembly that becomes locked when the module is loaded.

	Import-WebModule invokes Save-WebFile to download and save the file.  The Uri, CertificateValidator, and SecurityPolicy parameters are passed to Save-WebFile unaltered.

	.PARAMETER Uri
	The Uri from which to download the module. This parameter is passed to Save-WebFile unaltered.  See help Save-WebFile for more information.

	.PARAMETER ModuleSpec
	The module specification used to select the Uri from SourceLookup.

	.PARAMETER SourceLookup
	A hashtable used by Import-WebModule to lookup the Uri, ManifestFileFilter, CertificateValidator, and SecurityPolicy for a module.

	It must be possible to convert each key of SourceLookup to ModuleSpec.

	Values of SourceLookup must either be convertible to Uri or a hashtable containing at least two entries: Uri and ManifestFileFilter.  When importing a module that requires other modules, SourceLookup should include a key value pair for each module that is required.

    .PARAMETER ManifestFileFilter
	A filter passed by Import-WebModule to Get-ChildItem to select the manifest file for the module.

	.PARAMETER CertificateValidator
	This parameter is passed to Save-WebFile unaltered.  See help Save-WebFile for more information.

	.PARAMETER SecurityPolicy
	This parameter is passed to Save-WebFile unaltered.  See help Save-WebFile for more information.

    .PARAMETER PassThru
    Returns the object output by the calls to Import-Module -PassThru. By default, this cmdlet does not generate any output.
    #>
	[OutputType([psmoduleinfo])]
    [CmdletBinding(DefaultParameterSetName = 'Uri')]
    param
    (
        [Parameter(ParameterSetName = 'hashtable',
                   ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   Mandatory)]
        [Microsoft.PowerShell.Commands.ModuleSpecification]
        $ModuleSpec,

        [Parameter(ParameterSetName = 'hashtable',
                   Position = 1,
                   ValueFromPipelineByPropertyName,
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

		[Parameter(ParameterSetName = 'Uri')]
        [scriptblock]
        $CertificateValidator,

		[Parameter(ParameterSetName = 'Uri')]
        [BootstraPS.Policy.Strictness]
        $SecurityPolicy,

        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]
        $PassThru
    )
    process
    {
        if ( $PSCmdlet.ParameterSetName -eq 'Uri' )
        {
            [pscustomobject]@{
                ModuleSpec = 'nameless'
                SourceLookup = @{
                    nameless = [hashtable]$PSBoundParameters |
                        %{ $_.Remove('PassThru'); $_ }
                }
                PassThru = $PassThru
            } |
                Import-WebModule
            return
        }

        $sourceArgs = $ModuleSpec |
            Find-WebModuleSource $SourceLookup |
            ConvertTo-WebModuleSourceArgs

        $sourceArgs |
            Save-WebModule | Afterward {
                Write-Verbose "Removing downloaded file at $_"
                $_ | Remove-Item
            } |
            Expand-WebModule | Afterward {
                Write-Verbose "Attempting to remove module files at $_"
                $_ | Remove-Item -Recurse -ErrorAction SilentlyContinue
            } |
            % {
                $sourceArgs |
                    Find-ManifestFile $_.FullName |
                    % {
                        $_ |
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

Export-ModuleMember @(
    'Import-WebModule'
    'Save-WebFile'
    'Get-ValidationObject'
    '*X509*'
    '*Oid*'
    'Assert-SignatureAlgorithm'
    'Get-7d4176b6'
    '*SchannelRegistry*'
    '*SchannelPolicy*'
    'Set-RegistryProperty'
    '*SpManager*'
)