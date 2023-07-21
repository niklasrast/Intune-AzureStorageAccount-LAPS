<#
    .SYNOPSIS 
    Windows 10 Software packaging wrapper

    .DESCRIPTION
    Install:   C:\Windows\SysNative\WindowsPowershell\v1.0\PowerShell.exe -ExecutionPolicy Bypass -Command .\Install-ILAPS-Service.ps1 -install
    Uninstall:   C:\Windows\SysNative\WindowsPowershell\v1.0\PowerShell.exe -ExecutionPolicy Bypass -Command .\Install-ILAPS-Service.ps1 -uninstall

    .ENVIRONMENT
    PowerShell 5.0

    .AUTHOR
    Niklas Rast
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory = $true, ParameterSetName = 'install')]
	[switch]$install,
	[Parameter(Mandatory = $true, ParameterSetName = 'uninstall')]
	[switch]$uninstall
)

$ErrorActionPreference = "SilentlyContinue"
$logFile = ('{0}\{1}.log' -f "C:\Windows\Logs", [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name))

#Test if registry folder exists
if ($true -ne (test-Path -Path "HKLM:\SOFTWARE\COMPANY")) {
    New-Item -Path "HKLM:\SOFTWARE\" -Name "COMPANY" -Force
}

if ($install)
{
    Start-Transcript -path $logFile -Append

    #Create Script Folder
    New-Item -Path "C:\Windows\" -ItemType Directory -Name "IntuneLAPS"

    #Copy Script
    Copy-Item -Path "$PSScriptRoot\Intune-LAPS.ps1" -Destination "C:\Windows\IntuneLAPS" -Force

    #Register Schedule Task
    Register-ScheduledTask -Xml (Get-Content "$PSScriptRoot\IntuneLAPS.xml" | Out-String) -TaskName "IntuneLAPS" -Force

    #Initial run
    Start-Sleep -Seconds 5
    Start-ScheduledTask -TaskName "IntuneLAPS"

    #Register package in registry
    New-Item -Path "HKLM:\SOFTWARE\COMPANY\" -Name "ILAPS-Service"
    New-ItemProperty -Path "HKLM:\SOFTWARE\COMPANY\ILAPS-Service" -Name "Version" -PropertyType "String" -Value "3.0.0" -Force

    Stop-Transcript 
}

if ($uninstall)
{
    Start-Transcript -path $logFile -Append

    #Unregister Schedule Task
    Unregister-ScheduledTask -TaskName "IntuneLAPS" -Confirm:$false

    #Remove Script Folder
    Remove-Item -Path "C:\Windows\IntuneLAPS" -Recurse -Force

    #Register package in registry
    Remove-Item -Path "HKLM:\SOFTWARE\COMPANY\ILAPS-Service" -Recurse -Force 

}
