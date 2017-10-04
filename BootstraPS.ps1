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
begin
{
    function Find-WebModuleSource
    {
        param
        (
            [Parameter(ValueFromPipeline,
                       Mandatory)]
            [Microsoft.PowerShell.Commands.ModuleSpecification]
            $ModuleSpec,

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
            $uri = [uri]($SourceLookup.$match)
            Write-Verbose "Found source $uri for module $ModuleSpec."
            try
            {
                $uri
            }
            catch
            {
                throw [System.Exception]::new(
                    ("Uri: $uri",
                    "Module Spec: $ModuleSpec" -join [System.Environment]::NewLine),
                    $_.Exception
                )
            }
        }        
    }

    function Assert-Https
    {
        param
        (
            [Parameter(ValueFromPipeline,
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
            Invoke-WebRequest $Uri -OutFile $archivePath
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
            [Parameter(ValueFromPipelineByPropertyName,
                       Mandatory)]
            [string]
            [Alias('FullName')]
            $Path
        )
        process
        {
            $manifestFile = $Path | Get-ChildItem -Filter *.psd1 -Recurse
            $count = $manifestFile | measure | % Count
            if ( $count -gt 1 )
            {
                throw "Found more than one manifest file in the folder tree rooted at $Path."
            }
            if ( $count -lt 1 )
            {
                throw "Did not find a manifest file in the folder tree rooted at $Path."
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
        param
        (
            [Parameter(ValueFromPipeline,
                       Mandatory)]
            [Microsoft.PowerShell.Commands.ModuleSpecification]
            $ModuleSpec,

            [hashtable]
            $SourceLookup
        )
        process
        {
            Find-WebModuleSource @PSBoundParameters |
                Assert-Https |
                Save-WebModule |
                Expand-WebModule |
                Find-ManifestFile |
                % {
                    $_ |
                        Get-RequiredModule |
                        Import-WebModule -SourceLookup $SourceLookup
                    $_
                } |
                % FullName | 
                % { 
                    Write-Verbose "Importing module $_"
                    $_ | Import-Module -ErrorAction Stop
                }
        }        
    }
}
process
{
    Import-WebModule @PSBoundParameters
}