# MEM-Intune-AzureStorageAccount-LAPS

![GitHub repo size](https://img.shields.io/github/repo-size/niklasrast/MEM-Intune-AzureStorageAccount-LAPS)

![GitHub issues](https://img.shields.io/github/issues-raw/niklasrast/MEM-Intune-AzureStorageAccount-LAPS)

![GitHub last commit](https://img.shields.io/github/last-commit/niklasrast/MEM-Intune-AzureStorageAccount-LAPS)

This repository contains an script to create an LAPS solution based on PowerShell and an Azure Table in an Azure Storage Account for individual local admin password on Windows clients. The password is changed through an schedule task on the windows client - default every Monday.

## LAPS Workflow:
<img src="img\workflow.png"/>

## Install:
```powershell
C:\Windows\SysNative\WindowsPowershell\v1.0\PowerShell.exe -ExecutionPolicy Bypass -Command .\Install-ILAPS-Service.ps1 -install
```

## Uninstall:
```powershell
C:\Windows\SysNative\WindowsPowershell\v1.0\PowerShell.exe -ExecutionPolicy Bypass -Command .\Install-ILAPS-Service.ps1 -uninstall
```

In case that you need an solution to create individual local administrators and manage the credentials centraly ive created IntuneLAPS. This solution is based on an PowerShell Script which will be deployed as an Win32 application to windows clients and the credentials will be stored in an Azure Storage Account Table.

## Customer setup
At the beginning of the script you will find this line, in the quotes you can define the Username for your local administrator. I´ve choosed RecoveryAdmin:

```powershell
#Config variables (CUSTOMIZE TO TENANT)
$Username = "LOCALADMINNAME"
```
After the Username you can see the details to the storage account, SAS token and the table name. Please enter your details here:
```powershell
#Config variables (CUSTOMIZE TO TENANT)
$Description = "Built-in account from Microsoft Intune"
$AzureEndpoint = "https://ACCOUNTNAME.table.core.windows.net"
$storageAccount = "ACCOUNTNAME"
$AzureSharedAccessSignature  = 'SASTOKENFROMAZURE'
$AzureTable = "TABLENAME"
$AzureTableAccessKey = "ACCESSKEYFROMAZURE"
```
Save the script and convert it to .INTUNEWIN. Then create an Win32 application and deploy it to your clients to add and manage the local administrator. Use -install as an parameter to install the local admin account and if you need use -uninstall to remove it again.

## Azure Preperations:
- Create an Azure Storage Account
- Create an Table in the Storage Account (for example name it IntuneLAPS)
- Create an SAS Token
<img src="img\get-sastoken.png"/>
- Get the Access Key
<img src="img\get-accesskey.png"/>

## Get local Admin Passwords:
The credentials for each local administrator will be stored in the Table from the Azure Storage Account and you (plus everyone you´ve permitted) can be read from the Table through the Azure portal:
<img src="img\storageaccounttable.png"/>
The password will be a random 20-char sting as defined in the PowerShell script.

### Parameter definitions:
- -install configures the schedule task to change the local admin passwords.
- -uninstall removes the schedule task and the script from the client.
 
## Logfiles:
The scripts create a logfile with the name of the .ps1 script in the folder C:\Windows\Logs.

## Requirements:
- PowerShell 5.0
- Windows 10 or later
- Azure Storage Account with Table

# Feature requests
If you have an idea for a new feature in this repo, send me an issue with the subject Feature request and write your suggestion in the text. I will then check the feature and implement it if necessary.

Created by @niklasrast 
