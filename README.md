# MEM-Intune-AzureStorageAccount-LAPS

![GitHub repo size](https://img.shields.io/github/repo-size/niklasrast/MEM-Intune-AzureStorageAccount-LAPS)

![GitHub issues](https://img.shields.io/github/issues-raw/niklasrast/MEM-Intune-AzureStorageAccount-LAPS)

![GitHub last commit](https://img.shields.io/github/last-commit/niklasrast/MEM-Intune-AzureStorageAccount-LAPS)

This repository contains an script to create an LAPS solution based on PowerShell and an Azure Table in an Azure Storage Account for dynamic local admin password on Windows clients.

## Install:
```powershell
PowerShell.exe -ExecutionPolicy Bypass -Command .\Install-Intune-LAPS.ps1 -install
```

## Uninstall:
```powershell
PowerShell.exe -ExecutionPolicy Bypass -Command .\Install-Intune-LAPS.ps1 -uninstall
```

## Azure Preperations:
...to be created...

### Parameter definitions:
- -install configures the schedule task to change the local admin passwords.
- -uninstall removes the schedule task and the script from the client.
 
## Logfiles:
The scripts create a logfile with the name of the .ps1 script in the folder C:\Windows\Logs.

## Requirements:
- PowerShell 5.0
- Windows 10
- Azure Storage Account with Table

# Feature requests
If you have an idea for a new feature in this repo, send me an issue with the subject Feature request and write your suggestion in the text. I will then check the feature and implement it if necessary.

Created by @niklasrast 