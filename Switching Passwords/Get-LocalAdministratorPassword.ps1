#Requires -Version 3.0
<#
    .SYNOPSIS 
    Windows 10 Software packaging wrapper

    .DESCRIPTION
    Install:   PowerShell.exe -ExecutionPolicy Bypass -Command .\Reset-LocalAdministratorPassword.ps1

    .ENVIRONMENT
    PowerShell 5.0

    .AUTHOR
    Niklas Rast
#>

$SecretKey = "<GENERATESECRETKEY>"
$AzureEndpoint = 'https://<STORAGEACCOUNTNAME>.table.core.windows.net'
$AzureSharedAccessSignature  = '<SASTOKEN>'
$AzureTable = "<AZURETABLENAME>"


Function Test-InternetConnection
{
    [CmdletBinding()]
    
    Param
    (
        [parameter(Mandatory=$true)][string]$Target
    )

    #Test the connection to target.
    $Result = Test-NetConnection -ComputerName ($Target -replace "https://","") -Port 443 -WarningAction SilentlyContinue;

    #Return result.
    Return $Result;
}

#Get data from Azure tables.
Function Get-AzureTableData
{
    [CmdletBinding()]
    
    Param
    (
        [parameter(Mandatory=$true)][string]$Endpoint,
        [parameter(Mandatory=$true)][string]$SharedAccessSignature,
        [parameter(Mandatory=$true)][string]$Table
    )

    #Create request header.
    $Headers = @{
        "x-ms-date"=(Get-Date -Format r);
        "x-ms-version"="2016-05-31";
        "Accept-Charset"="UTF-8";
        "DataServiceVersion"="3.0;NetFx";
        "MaxDataServiceVersion"="3.0;NetFx";
        "Accept"="application/json;odata=nometadata"
    };

    #Construct URI.
    $URI = ($Endpoint + "/" + $Table + $SharedAccessSignature);

    #Insert data to Azure storage table.
    $Response = Invoke-WebRequest -Method Get -Uri $URI -Headers $Headers -UseBasicParsing;

    #Return table data.
    Return ,($Response.Content | ConvertFrom-Json).Value;
}

#Generate a secret key.
Function Set-SecretKey
{
    [CmdletBinding()]
    Param
    (
        [string]$Key
    )

    #Get key length.
    $Length = $Key.Length;
    
    #Pad length.
    $Pad = 32-$Length;
    
    #If the length is less than 16 or more than 32.
    If(($Length -lt 16) -or ($Length -gt 32))
    {
        #Throw exception.
        Throw "String must be between 16 and 32 characters";
    }
    
    #Create a new ASCII encoding object.
    $Encoding = New-Object System.Text.ASCIIEncoding;

    #Get byte array.
    $Bytes = $Encoding.GetBytes($Key + "0" * $Pad);

    #Return byte array.
    Return $Bytes;
}

#Encrypt data with a secret key.
Function Set-EncryptedData
{
    [CmdletBinding()]
    Param
    (
        $Key,
        [string]$TextInput
    )
    
    #Create a new secure string object.
    $SecureString = New-Object System.Security.SecureString;

    #Convert the text input to a char array.
    $Chars = $TextInput.ToCharArray();
    
    #Foreach char in the array.
    ForEach($Char in $Chars)
    {
        #Append the char to the secure string.
        $SecureString.AppendChar($Char);
    }
    
    #Encrypt the data from the secure string.
    $EncryptedData = ConvertFrom-SecureString -SecureString $SecureString -Key $Key;

    #Return the encrypted data.
    return $EncryptedData;
}

#Decrypt data with a secret key.
Function Get-EncryptedData
{
    [CmdletBinding()]
    Param
    (
        $Key,
        $TextInput
    )

    #Decrypt the text input with the secret key.
    $Result = $TextInput | ConvertTo-SecureString -key $Key | ForEach-Object {[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($_))};

    #Return the decrypted data.
    Return $Result;
}

#Test if the machine have internet connection.
If(!((Test-InternetConnection -Target $AzureEndpoint).TcpTestSucceeded -eq "true"))
{
    #Write out to the log file.
    #Write-Log -File $LogFile -Status Error -Text "No internet access.";

    #Exit the script with an error.
    Exit 1;
}

#Secret key.
$EncryptionKey = Set-SecretKey -Key ($SecretKey);

#Get all passwords.
$Data = Get-AzureTableData -Endpoint $AzureEndpoint -SharedAccessSignature $AzureSharedAccessSignature -Table $AzureTable;

#Object array.
$Accounts = @();

#If there is any data.
If($Data)
{
    #Foreach password.
    Foreach($Account in $Data)
    {
        #Decrypt password.
        $Password = Get-EncryptedData -Key $EncryptionKey -TextInput $Account.Password;

        #Create a new object.
        $AccountObject = New-Object -TypeName PSObject;

        #Add value to the object.
        Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "SerialNumber" -Value ($Account).SerialNumber;
        Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Hostname" -Value ($Account).Hostname;
        Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Username" -Value ($Account).Account;
        Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Password" -Value ($Password).ToString();
        Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "PasswordChanged" -Value ([datetime]($Account).PasswordChanged);

        #Add to object array.
        $Accounts += $AccountObject;
    }
}
#If no entries are returned.
Else
{
    #Create a new object.
    $AccountObject = New-Object -TypeName PSObject;

    #Add value to the object.
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "SerialNumber" -Value "<empty>";
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Hostname" -Value "<empty>";
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Username" -Value "<empty>";
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Password" -Value "<empty>";
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "PasswordChanged" -Value "<empty>";

    #Add to object array.
    $Accounts += $AccountObject;
}

#Create GUI.
$Hostname = (Read-Host -Prompt "Please enter the Hostname youre looking for: ")
$Accounts | ? "Hostname" -match $Hostname | Out-GridView -Title "Operational services Intune LAPS" -PassThru;