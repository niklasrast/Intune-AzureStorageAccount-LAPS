#Requires -Version 3.0
<#
    .SYNOPSIS 
    Windows 10 Software packaging wrapper

    .DESCRIPTION
    Install:   PowerShell.exe -ExecutionPolicy Bypass -Command .\INSTALL-Intune-LAPS.ps1

    .ENVIRONMENT
    PowerShell 5.0

    .INSPIRATION
    http://blog.tofte-it.dk/powershell-intune-local-administrator-password-solution-ilaps/

    .AUTHOR
    Niklas Rast
#>


[CmdletBinding()]
param(
	[Parameter(Mandatory = $true, ParameterSetName = 'install')]
	[switch]$install,
	[Parameter(Mandatory = $true, ParameterSetName = 'uninstall')]
	[switch]$uninstall,
	[Parameter(Mandatory = $true, ParameterSetName = 'detect')]
	[switch]$detect
)

$ErrorActionPreference = "SilentlyContinue"
#Use "C:\Windows\Logs" for System Installs and "$env:TEMP" for User Installs
$logFile = ('{0}\{1}.log' -f "C:\Windows\Logs", [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name))
$Username = "RecoveryAdmin"

if ($install)
{
    Start-Transcript -path $logFile -Append
        try
        {         
            #Add File or Folder
            Copy-Item -Path "$PSScriptRoot\Reset-LocalAdministratorPassword.ps1" -Destination "C:\Windows\system32" -Recurse -Force

            #Initial Password
            $Password = "INITIAL2021!"

            $group = (gwmi win32_group -filter "LocalAccount = $TRUE And SID = 'S-1-5-32-544'" | select -expand name)

            $adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
            $existing = $adsi.Children | where {$_.SchemaClassName -eq 'user' -and $_.Name -eq $Username }

            if ($existing -eq $null) {

                Write-Host "Creating new local user $Username."
                & NET USER $Username $Password /add /y /expires:never
                
                Write-Host "Adding local user $Username to $group."
                & NET LOCALGROUP $group $Username /add

            }
            else {
                Write-Host "Setting password for existing local user $Username."
                $existing.SetPassword($Password)
            }

            Write-Host "Ensuring password for $Username never expires."
            & WMIC USERACCOUNT WHERE "Name='$Username'" SET PasswordExpires=FALSE


            #Install EXE or EXE
            Start-Process -FilePath "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList '-File C:\Windows\system32\Reset-LocalAdministratorPassword.ps1 -Verb RunAs' -Wait
    
        } 
        catch
        {
            $PSCmdlet.WriteError($_)
            return $false
        }
    Stop-Transcript
}

if ($uninstall)
{
    Start-Transcript -path $logFile -Append
        try
        {
            #Remove File or Folder
            Remove-Item -Path "C:\Windows\system32\Reset-LocalAdministratorPassword.ps1" -Recurse -Force    

            Write-Host "Removing $Username from System $ENV:COMPUTERNAME..."
            Remove-LocalUser -Name $Username -Confirm:$False -Verbose
        }
        catch
        {
            $PSCmdlet.WriteError($_)
            return $false
        }
    Stop-Transcript
}

if ($detect)
{
    Start-Transcript -path $logFile -Append
        try {
            #Detect File or Folder
            $detection = (Test-Path -Path "C:\Windows\system32\Reset-LocalAdministratorPassword.ps1")

            return $detection
        }
        catch {
            $PSCmdlet.WriteError($_)
            return $false
        }
    Stop-Transcript
}