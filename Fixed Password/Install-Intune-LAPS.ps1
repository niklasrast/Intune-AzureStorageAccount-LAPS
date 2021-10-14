#Requires -Version 3.0
<#
    .SYNOPSIS 
    Windows 10 Software packaging wrapper

    .DESCRIPTION
    Install:   PowerShell.exe -ExecutionPolicy Bypass -Command .\INSTALL-Intune-LAPS.ps1

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
#Use "C:\Windows\Logs" for System Installs and "$env:TEMP" for User Installs
$logFile = ('{0}\{1}.log' -f "C:\Windows\Logs", [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name))
$Username = "RecoveryAdmin"
$AzureEndpoint = 'https://<STORAGEACCOUNTNAME>.table.core.windows.net'
$AzureSharedAccessSignature  = '<SASTOKEN>'
$AzureTable = "<TABLENAME>"

if ($install)
{
    Start-Transcript -path $logFile -Append
        try
        {         
            Function Get-RandomAlphanumericString {
                [CmdletBinding()]
                Param (
                    [int] $length = 15
                )
                Begin{}
                Process{
                    Write-Output ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count $length  | % {[char]$_}) )
                }	
            }

            $Group = (Get-WmiObject win32_group -filter "LocalAccount = $TRUE And SID = 'S-1-5-32-544'" | Select-Object -expand name)
            $Password = (Get-RandomAlphanumericString)
            $Description = "Built-in account from Operational services"

            $adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
            $existing = $adsi.Children | Where-Object {$_.SchemaClassName -eq 'user' -and $_.Name -eq $Username }

            if ($null -eq $existing) {
                & NET USER $Username $Password /add /y /expires:never /passwordchg:no /comment:$Description
                & NET LOCALGROUP $Group $Username /add
            }
            else {
                $existing.SetPassword($Password)
            }

            & WMIC USERACCOUNT WHERE "Name='$Username'" SET PasswordExpires=FALSE

            Function Test-InternetConnection
            {
                [CmdletBinding()]
                Param
                (
                    [parameter(Mandatory=$true)][string]$Target
                )

                $Result = Test-NetConnection -ComputerName ($Target -replace "https://","") -Port 443 -WarningAction SilentlyContinue;
                Return $Result;
            }

            Function Add-AzureTableData
            {
                [CmdletBinding()]
                Param
                (
                    [parameter(Mandatory=$true)][string]$Endpoint,
                    [parameter(Mandatory=$true)][string]$SharedAccessSignature,
                    [parameter(Mandatory=$true)][string]$Table,
                    [parameter(Mandatory=$true)][hashtable]$TableData
                )

                $Headers = @{
                    "x-ms-date"=(Get-Date -Format r);
                    "x-ms-version"="2016-05-31";
                    "Accept-Charset"="UTF-8";
                    "DataServiceVersion"="3.0;NetFx";
                    "MaxDataServiceVersion"="3.0;NetFx";
                    "Accept"="application/json;odata=nometadata"
                };

                $URI
                $URI = ($Endpoint + "/" + $Table + "/" + $SharedAccessSignature);

                #Convert table data to JSON and encode to UTF8.
                $Body = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $TableData));

                #Insert data to Azure storage table.
                Invoke-WebRequest -Method Post -Uri $URI -Headers $Headers -Body $Body -ContentType "application/json" -UseBasicParsing | Out-Null;
            }

            Function ConvertTo-HashTable
            {
                [cmdletbinding()]
                Param
                (
                    [Parameter(Position=0,Mandatory=$True,ValueFromPipeline=$True)]
                    [object]$InputObject,
                    [switch]$NoEmpty
                )
                
                Process
                {
                    #Get propery names.
                    $Names = $InputObject | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name;

                    #Define an empty hash table.
                    $Hash = @{};

                    #Go through the list of names and add each property and value to the hash table.
                    $Names | ForEach-Object {$Hash.Add($_,$InputObject.$_)};

                    #If NoEmpty is set.
                    If ($NoEmpty)
                    {
                        #Define a new hash.
                        $Defined = @{};

                        #Get items from $hash that have values and add to $Defined.
                        $Hash.Keys | ForEach-Object {
                            #If hash item is not empty.
                            If ($Hash.item($_))
                            {
                                #Add to hashtable.
                                $Defined.Add(($_,$Hash.Item($_)));
                            }
                        }       
                        #Return hashtable.
                        Return $Defined;
                    }
                    #Return hashtable.
                    Return $Hash;
                }
            }

            If(!((Test-InternetConnection -Target $AzureEndpoint).TcpTestSucceeded -eq "true"))
            {
                Write-Host "Cannot access the storage account through network problems."
                Exit 1;
            }

            #Create a new object.
            $TableObject = New-Object -TypeName PSObject;
            Add-Member -InputObject $TableObject -Membertype NoteProperty -Name "PartitionKey" -Value ((Get-Random -Minimum 000000 -Maximum 999999)).ToString();
            Add-Member -InputObject $TableObject -Membertype NoteProperty -Name "RowKey" -Value (Get-Date -Format dd-MM-yyyy);

            ###Add values to the object here
            Add-Member -InputObject $TableObject -Membertype NoteProperty -Name "Hostname" -Value $env:COMPUTERNAME
            Add-Member -InputObject $TableObject -Membertype NoteProperty -Name "Username" -Value $Username
            Add-Member -InputObject $TableObject -Membertype NoteProperty -Name "Password" -Value $Password

            #Insert data to the Azure table.
            Add-AzureTableData -Endpoint $AzureEndpoint -SharedAccessSignature $AzureSharedAccessSignature -Table $AzureTable -TableData (ConvertTo-HashTable -InputObject $TableObject);
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
            Remove-LocalUser -Name $Username -Confirm:$False -Verbose
        }
        catch
        {
            $PSCmdlet.WriteError($_)
            return $false
        }
    Stop-Transcript
}