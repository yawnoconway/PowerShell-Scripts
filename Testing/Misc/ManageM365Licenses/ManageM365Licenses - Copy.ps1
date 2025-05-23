<#
=============================================================================================
Name:           Manage Microsoft 365 licenses using MS Graph PowerShell
Description:    This script can perform 10+ Office 365 reporting and management activities
website:        o365reports.com
Script by:      O365Reports Team

Script Highlights :
~~~~~~~~~~~~~~~~~

1.	The script uses MS Graph PowerShell module.
2.	Generates 5 Office 365 license reports.
3.	Allows you to perform 6 license management actions that include adding or removing licenses in bulk.
4.	License Name is shown with its friendly name like ‘Office 365 Enterprise E3’ rather than ‘ENTERPRISEPACK’.
5.	Automatically installs MS Graph PowerShell module (if not installed already) upon your confirmation.
6.	The script can be executed with an MFA enabled account too.
7.	Exports the report result to CSV.
8.	Exports license assignment and removal log file.


For detailed Script execution: https://o365reports.com/2022/09/08/manage-365-licenses-using-ms-graph-powershell
============================================================================================
#>
Param
(
    [Parameter(Mandatory = $false)]
    [string]$LicenseName,
    [string]$LicenseUsageLocation,
    [int]$Action,
    [switch]$MultipleActionsMode
)

function Connect_MgGraph {
    $MsGraphBetaModule =  Get-Module Microsoft.Graph.Beta -ListAvailable
    if($null -eq $MsGraphBetaModule)
    { 
        Write-host "Important: Microsoft Graph Beta module is unavailable. It is mandatory to have this module installed in the system to run the script successfully." 
        $confirm = Read-Host Are you sure you want to install Microsoft Graph Beta module? [Y] Yes [N] No  
        if($confirm -match "[yY]") 
        { 
            Write-host "Installing Microsoft Graph Beta module..."
            Install-Module Microsoft.Graph.Beta -Scope CurrentUser -AllowClobber
            Write-host "Microsoft Graph Beta module is installed in the machine successfully" -ForegroundColor Magenta 
        } 
        else
        { 
            Write-host "Exiting. `nNote: Microsoft Graph Beta module must be available in your system to run the script" -ForegroundColor Red
            Exit 
        } 
    }
    Write-Progress "Importing Required Modules..."
    Import-Module -Name Microsoft.Graph.Beta.Identity.DirectoryManagement
    Import-Module -Name Microsoft.Graph.Beta.Users
    Import-Module -Name Microsoft.Graph.Beta.Users.Actions
    Write-Progress "Connecting MgGraph Module..."
    Connect-MgGraph -Scopes "Directory.ReadWrite.All"
}
Function Open_OutputFile {
    #Open output file after execution 
    if ((Test-Path -Path $OutputCSVName) -eq "True") {
        if ($ActionFlag -eq "Report") {
            Write-Host Detailed license report is available in: -NoNewline -Foregroundcolor Yellow; Write-Host $OutputCSVName
            Write-Host The report has $ProcessedCount records.
        }
        elseif ($ActionFlag -eq "Mgmt") {
            Write-Host License assignment/removal log file is available in: -NoNewline -Foregroundcolor Yellow; Write-Host $OutputCSVName
        } 
        $Prompt = New-Object -ComObject wscript.shell  
        $UserInput = $Prompt.popup("Do you want to open output file?", 0, "Open Output File", 4)  
        If ($UserInput -eq 6) {  
            Invoke-Item "$OutputCSVName"  
        } 
    }
    else {
        Write-Host No records found
    }
    Write-Host `n~~ Script prepared by AdminDroid Community ~~`n -ForegroundColor Green
    Write-Host "~~ Check out " -NoNewline -ForegroundColor Green; Write-Host "admindroid.com" -ForegroundColor Yellow -NoNewline; Write-Host " to get access to 1800+ Microsoft 365 reports. ~~" -ForegroundColor Green `n`n
    Write-Progress -Activity Export CSV -Completed
}

#Get user's details
Function Get_UserInfo {
    $global:DisplayName = $_.DisplayName
    $global:UPN = $_.UserPrincipalName
    $global:Licenses = $_.AssignedLicenses.SkuId
    $SigninStatus = $_.AccountEnabled
    if ($SigninStatus -eq $False) { 
        $global:SigninStatus = "Disabled" 
    }
    else {
        $global:SigninStatus = "Enabled"
    }
    $global:Department = $_.Department
    $global:JobTitle = $_.JobTitle
    if ($null -eq $Department) {
        $global:Department = "-"
    }
    if ($null -eq $JobTitle) {
        $global:JobTitle = "-"
    }
}

Function Get_License_FriendlyName {
    $FriendlyName = @()
    $LicensePlan = @()    
    #Convert license plan to friendly name 
    foreach ($License in $Licenses) {   
        $LicenseItem = $SkuIdHash[$License]  
        $EasyName = $FriendlyNameHash[$LicenseItem]  
        if (!($EasyName)) {
            $NamePrint = $LicenseItem 
        }  
        else {
            $NamePrint = $EasyName 
        } 
        $FriendlyName = $FriendlyName + $NamePrint
        $LicensePlan = $LicensePlan + $LicenseItem
    }
    $global:LicensePlans = $LicensePlan -join ","
    $global:FriendlyNames = $FriendlyName -join ","
}

Function Set_UsageLocation {
    if ($LicenseUsageLocation -ne "") {
        "Assigning Usage Location $LicenseUsageLocation to $UPN" |  Out-File $OutputCSVName -Append
        Update-MgBetaUser -UserId $UPN -UsageLocation $LicenseUsageLocation
    }
    else {
        "Usage location is mandatory to assign license. Please set Usage location for $UPN" |  Out-File $OutputCSVName -Append
    }
}

Function Assign_Licenses {
    "Assigning $LicenseNames license to $UPN" | Out-File $OutputCSVName -Append
    Set-MgBetaUserLicense -UserId $UPN -AddLicenses @{SkuId = $SkuPartNumberHash[$LicenseNames] } -RemoveLicenses @() | Out-Null
    if ($?) {
        "License assigned successfully" | Out-File $OutputCSVName -Append
    }
    else {
        "License assignment failed" | Out-file $OutputCSVName -Append
    }
}

Function Remove_Licenses {
    $SkuPartNumber = @()
    foreach ($Temp in $License) {
        $SkuPartNumber += $SkuIdHash[$Temp]
    }
    $SkuPartNumber = $SkuPartNumber -join (",")
    Write-Progress -Activity "`n     Removing $SkuPartNumber license from $UPN "`n"  Processed users: $ProcessedCount"
    "Removing $SkuPartNumber license from $UPN" | Out-File $OutputCSVName -Append
    Set-MgBetaUserLicense -UserId $UPN -RemoveLicenses @($License) -AddLicenses @() | Out-Null
    if ($?) {
        "License removed successfully" | Out-File $OutputCSVName -Append
    }
    else {
        "License removal failed" | Out-file $OutputCSVName -Append
    }
}

Function main() {
    Disconnect-MgGraph -ErrorAction SilentlyContinue|Out-Null
    Connect_MgGraph
    Write-Host "`nNote: If you encounter module related conflicts, run the script in a fresh PowerShell window." -ForegroundColor Yellow
    $Result = ""  
    $Results = @() 
    $FriendlyNameHash = Get-Content -Raw -Path .\LicenseFriendlyName.txt -ErrorAction Stop | ConvertFrom-StringData
    $SkuPartNumberHash = @{} 
    $SkuIdHash = @{} 
    Get-MgBetaSubscribedSku -All | Select-Object SkuPartNumber, SkuId | ForEach-Object {
        $SkuPartNumberHash.add(($_.SkuPartNumber), ($_.SkuId))
        $SkuIdHash.add(($_.SkuId), ($_.SkuPartNumber))
    }

    Do {                 
        if ($Action -eq "") {                       
            Write-Host ""
            Write-host `nOffice 365 License Reporting -ForegroundColor Yellow
            Write-Host  "    1." -ForegroundColor Cyan
            Write-Host  "    2." -ForegroundColor Cyan
            Write-Host  "    3." -ForegroundColor Cyan
            Write-Host  "    4." -ForegroundColor Cyan
            Write-Host  "    5." -ForegroundColor Cyan
            Write-Host `nOffice 365 License Management -ForegroundColor Yellow
            Write-Host  "    6." -ForegroundColor Cyan
            Write-Host  "    7." -ForegroundColor Cyan
            Write-Host  "    8." -ForegroundColor Cyan
            Write-Host  "    9." -ForegroundColor Cyan
            Write-Host  "    10." -ForegroundColor Cyan
            Write-Host  "    11." -ForegroundColor Cyan
            Write-Host  "    0.Exit" -ForegroundColor Cyan
            Write-Host ""
            $GetAction = Read-Host 'Please choose the action to continue' 
        }
        else {
            $GetAction = $Action
        }

        Switch ($GetAction) {
            1 {
                
            }

            2 {
                
            }

            3 {
                
            }

            4 {
                
            }

            5 {
                
            }

            6 {
                
            }

            7 {
                
            }
       

            8 {
               
            }

            9 {
                
            }

            10 {
                
            }  

            11 {
                
            } 
        }
        if ($Action -ne "") {
            exit 
        }
        if ($MultipleActionsMode.ispresent) {                          
            Start-Sleep -Seconds 2
        } 
        else {
            Exit
        }
    }
    While ($GetAction -ne 0)
    Disconnect-MgGraph
    Write-Host "Disconnected active Microsoft Graph session"
    Clear-Host
}
. main