<#
.SYNOPSIS
    Riverbird Installer

.DESCRIPTION
    PowerShell script intended to be used with a different RMM in order to install the Riverbird agent.

.INPUTS
    No parameters. Variables are supposed to be set by the rmm solution this script is used in.

.OUTPUTS
    None

.LINK
    GitHub: https://github.com/MichaelSchoenburg/RiverbirdInstaller

.NOTES
    Author: Michael Schönburg
    Version: v1.0
    
    This projects code loosely follows the PowerShell Practice and Style guide, as well as Microsofts PowerShell scripting performance considerations.
    Style guide: https://poshcode.gitbook.io/powershell-practice-and-style/
    Performance Considerations: https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/performance/script-authoring-considerations?view=powershell-7.1
#>

#region FUNCTIONS
<# 
    Declare Functions
#>

function Write-ConsoleLog {
    <#
    .SYNOPSIS
    Logs an event to the console.
    
    .DESCRIPTION
    Writes text to the console with the current date (US format) in front of it.
    
    .PARAMETER Text
    Event/text to be outputted to the console.
    
    .EXAMPLE
    Write-ConsoleLog -Text 'Subscript XYZ called.'
    
    Long form
    .EXAMPLE
    Log 'Subscript XYZ called.
    
    Short form
    #>
    [alias('Log')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
        Position = 0)]
        [string]
        $Text
    )

    # Save current VerbosePreference
    # $VerbosePreferenceBefore = $VerbosePreference

    # Enable verbose output
    # $VerbosePreference = 'Continue'

    # Write verbose output
    Write-Output "$( Get-Date -Format 'MM/dd/yyyy HH:mm:ss' ) - $( $Text )"

    # Restore current VerbosePreference
    # $VerbosePreference = $VerbosePreferenceBefore
}

function Import-ModuleForSure {
    <#
    .SYNOPSIS
        Import a module

    .DESCRIPTION
        Imports and installs a module if it's not imported or installed already. Taking into account NuGet.

    .NOTES
        This function is pipeline ready.

    .PARAMETER Name
        Name of the PowerShell module

    .EXAMPLE
        Import-ModuleForSure -Name Posh-SSH
        Imports Posh-SSH for sure.
    #>
    
    param (
        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [string]
        $Name
    )
    
    begin {
        if (-not (Get-PackageProvider -Name NuGet) ) {
            Log 'Installing NuGet...'
            Install-PackageProvider -Name NuGet -Force
        }
    }
    
    process {
        Log 'Loading module $Name...'
        if (Get-Module -Name $Name) {
            Log "Module '$( $Name )' has been imported already."
        } elseif (Get-Module -Name $Name -ListAvailable) {
            Log 'Module '$( $Name )' has been installed already, but is not imported. Importing Module...'
            Import-Module -Name $Name
        } else {
            Log "Installing Module '$( $Name )'..."
            Install-Module -Name $Name -Force

            Log "Importing Module '$( $Name )..."
            Import-Module -Name $Name
        }
    }
    
    end {
        
    }
}

function Set-TailingSlash {
    [CmdletBinding()]
    param (
        # Name of the variable (as string)
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName)]
        [string]
        $VariableName,

        # Either '\' or '/' (as char)
        [Parameter(
            ValueFromPipelineByPropertyName
        )]
        [char]
        [ValidatePattern('\/|\\')]
        $Slash = '\'
    )
    
    begin {
        
    }
    
    process {
        $var = Get-Variable -Name $VariableName
        if ( 
            -not ( 
                $var.Value.EndsWith( $Slash )
            )
        ){ 
            $Value = $var.Value + $Slash
            Set-Variable -Name $VariableName -Value $Value -Scope Script
        }
    }
    
    end {
        
    }
}

#endregion FUNCTIONS
#region INITIALIZATION
<# 
    Libraries, Modules, ...
#>

try {
    # Check if PowerShell module for SFTP is installed already
    Import-ModuleForSure -Name 'Posh-SSH'

    #endregion INITIALIZATION
    #region DECLARATIONS
    <#
        Declare local variables and global variables
    #>

    # The following variables should be set through your rmm solution. 
    # Here some examples of possible declarations with explanations for each variable.
    # Tip: PowerShell variables are not case sensitive.

    <#
        # Example arguments
        $ExitCodeSuccess = 0
        $ExitCodeFail = 1001
        $monitoringVersion = '11.0.2401'
        $webServiceUrl1 = 'https://portal.MyRiverbirdServer.com/rmm'
        $webServiceUrl2 = ''
        $installationToken = 'Grf0l9BrCcGbPkcqxeJtgQ9FqU9PpFDBy71cHZejk0kUjhtjjCGjyVlgCdINZp6L'
        $proxyUrl = ''
        $proxyPort = ''
        $proxyBypassOnLocal = ''
        $proxyUseDefaultCredentials = ''
        $proxyDomain = ''
        $proxyUsername = ''
        $proxyPassword = ''
        $FtpServerFqdn = 'MyServer.com'
        $FtpUsername = 'MyUser'
        $FtpPassword = 'MyP4$$vv0rd'
        $NameInstallFile = 'Riverbird RMM Installer.exe'
        $DirSrc = '/home/CenterMANAGEMENT'
        $DirDest = 'C:\TSD.CenterVision\Software\Riverbird'
    #>

    # Make sure paths contain a tailing slash
    Set-TailingSlash -VariableName 'DirSrc' -Slash '/'
    Set-TailingSlash -VariableName 'DirDest' -Slash '\'

    # Define paths
    $FullPathSrc = $DirSrc + $NameInstallFile
    $FullPathInstaller = $DirDest + $NameInstallFile

    # Define arguments
    $Arguments = @(
        'install',
        "-token $( $installationToken )",
        "-url $( $webServiceUrl1 )",
        "-version $( $monitoringVersion )"
    )

    #endregion DECLARATIONS
    #region EXECUTION
    <# 
        Script entry point
    #>

    <# 
        Create directory for installation file
    #>

    # TODO: Check if is installed already

    Log "Checking if destination directory '$( $DirDest )' exists." 
    if (-not ( Test-Path -Path $DirDest )) {
        Log "Doesn't exist. Creating..."
        New-Item -Path $DirDest -ItemType Directory -Force
    } else {
        Log "Exist already."
    }

    <# 
        Connect to FTP server to receive installation file
    #>

    # Build credentials for FTP server
    $SecureString = ConvertTo-SecureString -AsPlainText $FtpPassword -Force
    $Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $FtpUsername, $SecureString 

    try {
        # Connect to FTP server
        $s = New-SFTPSession -ComputerName $FtpServerFqdn -Credential $Creds -Port 22 -AcceptKey:$true

        # Download installation file
        Get-SFTPItem -SFTPSession $s -Path $FullPathSrc -Destination $DirDest -Force # One can only specify a directory as destination. The file will always keep its name.
    }
    finally {
        # Disconnect from FTP server
        Remove-SFTPSession -SFTPSession $s
    }

    <# 
        Start installation
    #>

    Start-Process -FilePath $FullPathInstaller -ArgumentList $Arguments

    Log 'Started installation successfully. Exiting successfully...'
    Exit $ExitCodeSuccess

    #endregion EXECUTION
} catch {
    Log "An error occurred. Error Details:"
    Log "Exception Message: $( $PSItem.Exception.Message )"
    Log "Inner Exception Message: $( $PSItem.Exception.InnerException )"
    $PSItem.InvocationInfo | Format-List *
    Exit $ExitCodeFail
}
