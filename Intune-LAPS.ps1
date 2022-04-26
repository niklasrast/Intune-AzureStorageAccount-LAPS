#Requires -Version 3.0
<#
    .SYNOPSIS 
    Windows 10 Software packaging wrapper

    .DESCRIPTION
    Run:   C:\Windows\SysNative\WindowsPowershell\v1.0\PowerShell.exe -ExecutionPolicy Bypass -Command .\Intune-LAPS.ps1

    .ENVIRONMENT
    PowerShell 5.0

    .AUTHOR
    Niklas Rast
#>

#Config variables (CUSTOMIZE TO TENANT)
$Username = "LOCALADMINNAME"
$Description = "Built-in account from Operational services"
$AzureEndpoint = "https://ACCOUNTNAME.table.core.windows.net"
$storageAccount = "ACCOUNTNAME"
$AzureSharedAccessSignature  = 'SASTOKENFROMAZURE'
$AzureTable = "TABLENAME"
$AzureTableAccessKey = "ACCESSKEYFROMAZURE"

#Script variables (DO NOT CHANGE)
$ErrorActionPreference = "SilentlyContinue"
$logFile = ('{0}\{1}.log' -f "C:\Windows\Logs", [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name))

Start-Transcript -path $logFile -Append
    try
    {         
        Function Get-RandomAlphanumericString {
            [CmdletBinding()]
            Param (
                [int] $length = 20
            )
            Begin{}
            Process{
                Write-Output ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count $length  | % {[char]$_}) )
            }	
        }

        #Get LocalAdmin Group
        $Group = (Get-WmiObject win32_group -filter "LocalAccount = $TRUE And SID = 'S-1-5-32-544'" | Select-Object -expand name)
        #Generate new password
        $Password = (Get-RandomAlphanumericString)

        #Add new LAPS user or update password if existing
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

        #Check if Storage Account is available
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

        #Upload data to azure storage account table
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

            #Authentification header
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

        #Delete data from azure storage account table
        function DeleteTableEntity($PartitionKey,$RowKey) {
            $version = "2017-04-17"
            $resource = "$AzureTable(PartitionKey='$PartitionKey',RowKey='$Rowkey')"
	        $table_url = "$AzureEndpoint/$resource"
            $GMTTime = (Get-Date).ToUniversalTime().toString('R')
            $stringToSign = "$GMTTime`n/$storageAccount/$resource"
            $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
            $hmacsha.key = [Convert]::FromBase64String($AzureTableAccessKey)
            $signature = $hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
            $signature = [Convert]::ToBase64String($signature)
            
            #Authentification header
            $headers = @{
                'x-ms-date'    = $GMTTime
                Authorization  = "SharedKeyLite " + $storageAccount + ":" + $signature
                "x-ms-version" = $version
                Accept         = "application/json;odata=minimalmetadata"
                'If-Match'     = "*"
            }

            #Delete data from the Azure table.
            Invoke-RestMethod -Method DELETE -Uri $table_url -Headers $headers -ContentType application/http
        }

        #Convert data to hash table to pipe it to upload function
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

        #Check if Storage Account is available, if not stop
        If(!((Test-InternetConnection -Target $AzureEndpoint).TcpTestSucceeded -eq "true"))
        {
            Write-Host "Cannot access the storage account through network problems."
            Exit 1;
        }

        #Variables
        $Serial = (Get-WmiObject win32_bios).Serialnumber

        #Remove old entries
        try 
        {
            #Send the delete request to MS Graph
            DeleteTableEntity -PartitionKey $Serial -RowKey $Serial | Out-Null
        }
        catch 
        {
            #Catch error if request fails or entry was not found
            Write-Host "First time running this script on this client - Skip delete old entry"
        }

        #Wait 5 Seconds
        Start-Sleep -Seconds 5

        #Create a new object.
        $TableObject = New-Object -TypeName PSObject;
        Add-Member -InputObject $TableObject -Membertype NoteProperty -Name "PartitionKey" -Value $Serial
        Add-Member -InputObject $TableObject -Membertype NoteProperty -Name "RowKey" -Value $Serial

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