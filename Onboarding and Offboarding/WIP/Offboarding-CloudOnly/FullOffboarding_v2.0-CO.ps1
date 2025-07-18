#Requires -Modules ExchangeOnlineManagement, Microsoft.Graph

<#
.SYNOPSIS
    Complete user offboarding script for M365.
.DESCRIPTION
    This script automates the offboarding process for users by:
    - Disabling M365 account
    - Changing password to a random value
    - Modifying user attributes
    - Clearing manager field
    - Capturing and removing group memberships
    - Hiding from GAL
    - Wiping/blocking mobile devices
    - Converting to shared mailbox
    - Setting mailbox permissions
    - Removing licenses
    - Removing from 365 groups
.NOTES
    Version: 2.0
    Updated: June 23, 2025
    Author: Josh Conway
    Previous: v1.5
    Changelog:
        2.0 - Code rewrite - function based
              Added        - error catching, logging, success/failure tracking, script config
              Removed      - hardcoded file paths
              Changed      - Split for cloud only and cloud+local, new password generator

        1.5 - Now clears manager field, grabs group memberships, wipes mobile outlook containers, removed mailbox foward,
              added mailbox full access, and connects to Graph to removes 365 groups and licenses
        
        1.2 - Will now modify Emp Status and Ext Attr 14 to "Inactive"
        
        1.1 - Added moving to disabled OU, and a list of script functions

        1.0 - Initial version
#>

#-----------------------------
# Configuration
#-----------------------------
$Script:Config = @{
    # Paths
    GroupMembershipExportPath = "$PSScriptRoot\Group Memberships"
    BulkImportPath            = "$PSScriptRoot\Bulk-Offboarding.csv"
    
    # Account Domain
    Domain                    = "DOMAIN.com"
    
    # ASCII Banner Path
    BannerFile                = "$PSScriptRoot\banner.txt"
    
    # Logging
    LogFile                   = "$PSScriptRoot\OffboardingLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    
    # Other settings
    PasswordLength            = 20
}

#-----------------------------
# Initialize Logging
#-----------------------------
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info',
        
        [Parameter(Mandatory = $false)]
        [switch]$NoConsole
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Add to log file
    Add-Content -Path $Script:Config.LogFile -Value $logEntry
    
    # Output to console with color-coding
    if (-not $NoConsole) {
        $color = switch ($Level) {
            'Info' { 'White' }
            'Warning' { 'Yellow' }
            'Error' { 'Red' }
            default { 'White' }
        }
        Write-Host $logEntry -ForegroundColor $color
    }
}

#-----------------------------
# Module Management
#-----------------------------
function Initialize-RequiredModules {
    [CmdletBinding()]
    param()
    
    Write-Log "Checking required modules..."
    
    $modules = @(
        @{Name = "ExchangeOnlineManagement"; Required = $true },
        @{Name = "Microsoft.Graph"; Required = $true }
    )
    
    foreach ($module in $modules) {
        try {
            if (!(Get-Module $module.Name -ListAvailable -ErrorAction SilentlyContinue)) {
                Write-Log "Module $($module.Name) not found. Attempting to import..." -Level Warning
                Import-Module $module.Name -ErrorAction Stop
                Write-Log "Successfully imported $($module.Name)"
            }
            else {
                Write-Log "Module $($module.Name) already available"
                Import-Module $module.Name -ErrorAction Stop
            }
        }
        catch {
            $errorMsg = "Failed to import $($module.Name): $($_.Exception.Message)"
            Write-Log $errorMsg -Level Error
            if ($module.Required) {
                throw $errorMsg
            }
        }
    }
}

#-----------------------------
# Connection Management
#-----------------------------
function Connect-RequiredServices {
    [CmdletBinding()]
    param()
    
    Write-Log "Connecting to required services..."
    
    # Connect to Exchange Online if not already connected
    try {
        $getSessions = Get-ConnectionInformation | Select-Object Name
        $isConnected = (@($getSessions.Name) -like 'ExchangeOnline*').Count -gt 0
        If ($isConnected -ne 'True') {
            Write-Log "Connecting to Exchange Online..."
            Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
            Write-Log "Successfully connected to Exchange Online"
        }
        else {
            Write-Log "Already connected to Exchange Online"
        }
    }
    catch {
        Write-Log "Failed to connect to Exchange Online: $($_.Exception.Message)" -Level Error
        throw "Exchange Online connection failed. Please ensure you have the proper credentials."
    }
    
    # Connect to Microsoft Graph if not already connected
    try {
        Write-Log "Connecting to Microsoft Graph..."
        Connect-Graph -Scopes User.ReadWrite.All, Organization.Read.All, Group.ReadWrite.All -ErrorAction Stop
        Write-Log "Successfully connected to Microsoft Graph"
    }
    catch {
        Write-Log "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -Level Error
        throw "Microsoft Graph connection failed. Please ensure you have the proper credentials."
    }
}

#-----------------------------
# User Account Functions
#-----------------------------
function Get-RandomPassword {
    [CmdletBinding()]
    param(
        [int]$Length = $Script:Config.PasswordLength
    )
    
    # Generate a more complex password with upper, lower, numbers, and special chars
    $upper = [char[]](65..90)
    $lower = [char[]](97..122)
    $numbers = [char[]](48..57)
    $special = [char[]](33..47 + 58..64 + 91..96 + 123..126)
    
    # Ensure at least one of each type
    $password = @()
    $password += $upper | Get-Random
    $password += $lower | Get-Random
    $password += $numbers | Get-Random
    $password += $special | Get-Random
    
    # Fill the rest randomly
    $remainingLength = $Length - 4
    $allChars = $upper + $lower + $numbers + $special
    $password += $allChars | Get-Random -Count $remainingLength
    
    # Shuffle the password characters
    $password = $password | Sort-Object { Get-Random }
    
    return -join $password
}

function Disable-M365UserAccount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserMail
    )

    try {
        $user = Get-MgUser -UserId $UserMail -ErrorAction Stop

        if ($user.AccountEnabled -eq $false) {
            Write-Log "$UserMail is already disabled"
        }
        else {
            Update-MgUser -UserId $UserMail -AccountEnabled:$false -ErrorAction Stop
            Write-Log "Successfully disabled account for $UserMail"
        }
        return $true
    }
    catch {
        Write-Log "Failed to disable account for ${UserMail}: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Set-M365UserPassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserMail,

        [Parameter(Mandatory = $false)]
        [SecureString]$Password = (Get-RandomPassword)
    )

    try {
        $PlainPassword = [System.Net.NetworkCredential]::new("", $Password).Password

        Update-MgUser -UserId $UserMail -PasswordProfile @{
            Password                      = $PlainPassword
            ForceChangePasswordNextSignIn = $false
        } -ErrorAction Stop

        Write-Host "Successfully changed password for $UserMail"
        return $true
    }
    catch {
        Write-Host "Failed to change password for ${UserMail}: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Set-UserAttributes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserMail
    )
    
    try {
        # Clear attributes
        Update-MgUser -UserId $UserMail -Department $null -JobTitle $null -ErrorAction Stop
        
        # Clear manager field
        Remove-MgUserManagerByRef -UserId $UserMail -ErrorAction Stop
        
        Write-Log "Successfully updated attributes for $UserMail"
        return $true
    }
    catch {
        Write-Log "Failed to update attributes for ${UserMail}: $($_.Exception.Message)" -Level Error
        return $false
    }
}

#-----------------------------
# Group Membership Functions
#-----------------------------
function Export-GroupMemberships {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserMail
    )
    
    try {
        # Ensure export directory exists
        if (-not (Test-Path -Path $Script:Config.GroupMembershipExportPath)) {
            New-Item -Path $Script:Config.GroupMembershipExportPath -ItemType Directory -Force | Out-Null
        }
        
        $exportPath = Join-Path -Path $Script:Config.GroupMembershipExportPath -ChildPath "$Username.csv"
        
        # Export Microsoft 365 group memberships
        Get-MgUserMemberOf -UserId $UserMail | 
        ForEach-Object { Get-MgGroup -GroupId $_.Id } | 
        Select-Object DisplayName | 
        Export-Csv -Path $exportPath -NoTypeInformation -ErrorAction Stop
        
        Write-Log "Successfully exported group memberships for $UserMail to $exportPath"
        return $true
    }
    catch {
        Write-Log "Failed to export group memberships for ${UserMail}: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Remove-UserFrom365Groups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserMail
    )
    
    try {
        $mguser = Get-MgUser -UserId $UserMail -ErrorAction SilentlyContinue
        
        if ($mguser) {
            $msgroupMemberships = @(Get-MgUserMemberof -UserId $mguser.id -ErrorAction Stop)
            
            if (!$msgroupMemberships) {
                Write-Log "No 365 groups found for $UserMail"
            }
            else {
                foreach ($group in $msgroupMemberships) {
                    try {
                        Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $mguser.id -Confirm:$false -ErrorAction Stop
                        Write-Log "Removed $UserMail from 365 group: $($group.DisplayName)" -NoConsole
                    }
                    catch {
                        Write-Log "Failed to remove $UserMail from 365 group: $($_.Exception.Message)" -Level Warning -NoConsole
                    }
                }
                Write-Log "Successfully removed $UserMail from all 365 groups"
            }
            return $true
        }
        else {
            Write-Log "User $UserMail not found in 365. Please verify group removal in portal." -Level Warning
            return $false
        }
    }
    catch {
        Write-Log "Failed to remove $UserMail from 365 groups: $($_.Exception.Message)" -Level Error
        return $false
    }
}

#-----------------------------
# Mailbox Functions
#-----------------------------
function Set-HideFromAddressLists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserMail
    )

    try {
        # Hide from address lists
        Set-Mailbox -Identity $UserMail `
            -HiddenFromAddressListsEnabled $true `
            -ErrorAction Stop

        Write-Host "Successfully hid $UserMail from GAL"
        return $true
    }
    catch {
        Write-Host "Failed to hide $UserMail from GAL: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Set-MailboxToShared {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserMail,
        
        [Parameter(Mandatory = $false)]
        [string]$FullAccessUser = ""
    )
    
    try {
        # Convert to shared mailbox
        Set-Mailbox -Identity $UserMail -Type Shared -ErrorAction Stop
        Write-Log "Successfully converted $UserMail to shared mailbox"
        
        # Add full access if specified
        if (-not [string]::IsNullOrEmpty($FullAccessUser)) {
            $FullAccessAddress = "$FullAccessUser@$($Script:Config.Domain)"
            Add-MailboxPermission -Identity $UserMail -User $FullAccessAddress -AccessRights FullAccess -InheritanceType All -ErrorAction Stop
            Write-Log "Successfully granted $FullAccessAddress full access to $UserMail"
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to set mailbox options for ${UserMail}: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Clear-MobileDevices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserMail
    )
    
    try {
        # iOS/Android/ActiveSync Devices
        $MobileDevices = Get-MobileDevice -Identity $UserMail -ResultSize unlimited | 
        Where-Object { ($_.ClientType -eq "EAS") -or ($_.DeviceModel -eq "Outlook for iOS and Android") }

        foreach ($MobileDevice in $MobileDevices) {
            Clear-MobileDevice $MobileDevice.Identity -AccountOnly -Confirm:$false -ErrorAction Stop
            Write-Log "Cleared mobile device $($MobileDevice.DeviceModel) for $UserMail" -NoConsole
        }

        # Mac/Windows etc.
        $OtherDevices = Get-MobileDevice -Mailbox $UserMail -ResultSize unlimited | 
        Where-Object { ($_.ClientType -ne "EAS") -and ($_.DeviceModel -ne "Outlook for iOS and Android") }
            
        foreach ($OtherDevice in $OtherDevices) {
            try {
                Clear-MobileDevice $OtherDevice.Identity -AccountOnly -Confirm:$false -ErrorAction Stop
                Write-Log "Cleared device $($OtherDevice.DeviceModel) for $UserMail" -NoConsole
            }
            catch {
                Write-Log "Account-only wipe failed for device $($OtherDevice.DeviceModel). Blocking device instead." -Level Warning -NoConsole
                $BlockedDeviceIDs = @($OtherDevice.DeviceID)
                Set-CASMailbox $UserMail -ActiveSyncBlockedDeviceIDs $BlockedDeviceIDs -ErrorAction Stop
                Write-Log "Blocked device $($OtherDevice.DeviceModel) for $UserMail" -NoConsole
            }
        }
        
        Write-Log "Successfully processed all mobile devices for $UserMail"
        return $true
    }
    catch {
        Write-Log "Failed to process mobile devices for ${UserMail}: $($_.Exception.Message)" -Level Error
        return $false
    }
}

#-----------------------------
# License Functions
#-----------------------------
function Remove-UserLicenses {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserMail
    )
    
    try {
        $mguser = Get-MgUser -UserId $UserMail -ErrorAction SilentlyContinue
        
        if ($mguser) {
            $SKUs = @(Get-MgUserLicenseDetail -UserId $mguser.id -ErrorAction Stop)
            
            if (!$SKUs) {
                Write-Log "No licenses found for $UserMail"
            }
            else {
                foreach ($SKU in $SKUs) {
                    try {
                        Write-Log "Removing license $($SKU.SkuPartNumber) from $UserMail" -NoConsole
                        Set-MgUserLicense -UserId $mguser.id -AddLicenses @() -RemoveLicenses $Sku.SkuId -ErrorAction Stop
                    }
                    catch {
                        if ($_.Exception.Message -eq "User license is inherited from a group membership and it cannot be removed directly from the user.") {
                            Write-Log "License $($SKU.SkuPartNumber) is assigned via group-based licensing. Please remove manually." -Level Warning
                        }
                        else {
                            Write-Log "Failed to remove license $($SKU.SkuPartNumber): $($_.Exception.Message)" -Level Warning
                        }
                    }
                }
                Write-Log "Successfully processed license removal for $UserMail"
            }
            return $true
        }
        else {
            Write-Log "User $UserMail not found in 365. Please verify license removal in portal." -Level Warning
            return $false
        }
    }
    catch {
        Write-Log "Failed to remove licenses for ${UserMail}: $($_.Exception.Message)" -Level Error
        return $false
    }
}

#-----------------------------
# Main Offboarding Function
#-----------------------------
function Start-UserOffboarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $false)]
        [string]$FullAccessUser = ""
    )
    
    # Initialize variables
    $UserMail = "$Username@$($Script:Config.Domain)"
    $Password = Get-RandomPassword
    
    Write-Log "Starting offboarding process for $Username" -Level Info
    
    # Track success/failure for each step
    $results = @{
        "Disable Account"        = Disable-M365UserAccount -UserMail $UserMail
        "Set Password"           = Set-M365UserPassword -UserMail $UserMail -Password $Password
        "Set Attributes"         = Set-UserAttributes -UserMail $UserMail
        "Export Groups"          = Export-GroupMemberships -UserMail $UserMail
        "Hide from GAL"          = Set-HideFromAddressLists -UserMail $UserMail
        "Set Mailbox to Shared"  = Set-MailboxToShared -UserMail $UserMail -FullAccessUser $FullAccessUser
        "Remove Licenses"        = Remove-UserLicenses -UserMail $UserMail
        "Remove from 365 Groups" = Remove-UserFrom365Groups -UserMail $UserMail
    }
    
    # Optional: Uncomment/add below to above list to enable mobile device wipe
    # $results["Clear Mobile Devices"] = Clear-MobileDevices -UserMail $UserMail
    
    # Count successes and failures
    $successful = ($results.Values | Where-Object { $_ -eq $true }).Count
    $failed = ($results.Values | Where-Object { $_ -eq $false }).Count
    $total = $results.Count
    
    # Log summary
    Write-Log "Offboarding summary for ${Username}:" -Level Info
    Write-Log "Successful operations: $successful/$total" -Level Info
    
    if ($failed -gt 0) {
        Write-Log "Failed operations: $failed/$total" -Level Warning
        foreach ($key in $results.Keys) {
            if ($results[$key] -eq $false) {
                Write-Log "- $key" -Level Warning
            }
        }
    }
    
    return ($failed -eq 0)
}

#-----------------------------
# Main Script
#-----------------------------
function Show-Banner {
    $bannerText = @'
   __  __                                                                        
  / / / /_______  _____                                                          
 / / / / ___/ _ \/ ___/                                                          
/ /_/ (__  )  __/ /                                                              
\____/____/\___/_/_                         ___                     ___          
  / __ \/ __/ __/ /_  ____  ____ __________/ (_)___  ____ _        |__ \    ___  
 / / / / /_/ /_/ __ \/ __ \/ __ `/ ___/ __  / / __ \/ __ `/   _  __ _/ /   / _ \ 
/ /_/ / __/ __/ /_/ / /_/ / /_/ / /  / /_/ / / / / / /_/ /   | |/ / __/   / // / 
\____/_/ /_/ /_.___/\____/\__,_/_/   \__,_/_/_/ /_/\__, /    |___/____/(_)\___/  
                                                  /____/                         
'@

    Write-Host $bannerText -ForegroundColor Yellow
    
    $infoText = @"
This script will do the following in this order:

           1. Disable M365 account
           2. Change password
           3. Clear user attributes (Department, Job Title)
           4. Clear manager field
           5. Capture group memberships and export as csv
           6. Hide from GAL
           7. **Wipe and/or block mobile device outlook containers** (Disabled by default)
           8. Convert to shared mailbox
           9. Set mailbox 'Full Access' permission if specified
          10. Remove 365 licenses from user
          11. Removes user from 365 groups
"@
    
    Write-Host $infoText -ForegroundColor Cyan
}

function Start-OffboardingProcess {
    [CmdletBinding()]
    param()
    
    # Start log
    Write-Log "Starting User Offboarding Script" -Level Info
    
    # Show banner
    Show-Banner
    
    # Initialize modules and connections
    try {
        Initialize-RequiredModules
        Connect-RequiredServices
    }
    catch {
        Write-Log "Critical error in initialization: $($_.Exception.Message)" -Level Error
        return
    }
    
    $OffboardingComplete = $false
    
    while (-not $OffboardingComplete) {
        try {
            $answer = Read-Host "Are you offboarding a single user, or in bulk? (Single/Bulk)"
            
            switch ($answer) {
                "Single" {
                    # Single user offboarding
                    $Username = Read-Host "Enter the username of the employee to be offboarded"
                    $FullAccessUser = Read-Host "Enter the username for who will gain full access to mailbox. Leave blank for no one"
                    
                    $success = Start-UserOffboarding -Username $Username -FullAccessUser $FullAccessUser
                    
                    if ($success) {
                        Write-Log "Successfully completed offboarding for $Username" -Level Info
                        $OffboardingComplete = $true
                    }
                    else {
                        Write-Log "Offboarding completed with some errors for $Username" -Level Warning
                        $retry = Read-Host "Do you want to retry? (Y/N)"
                        if ($retry -eq "Y") {
                            continue
                        }
                        else {
                            $OffboardingComplete = $true
                        }
                    }
                }
                
                "Bulk" {
                    $confirmation = Read-Host "Are you sure you want to proceed with Bulk User offboarding? (Y/N)"
                    
                    if ($confirmation -eq "Y") {
                        # Check if CSV file exists
                        if (-not (Test-Path -Path $Script:Config.BulkImportPath)) {
                            Write-Log "Bulk import file not found at $($Script:Config.BulkImportPath)" -Level Error
                            continue
                        }
                        
                        # Import the CSV
                        try {
                            $users = Import-Csv -Path $Script:Config.BulkImportPath -ErrorAction Stop
                            Write-Log "Successfully imported $($users.Count) users from CSV" -Level Info
                        }
                        catch {
                            Write-Log "Failed to import CSV: $($_.Exception.Message)" -Level Error
                            continue
                        }
                        
                        # Process each user
                        $successCount = 0
                        $failCount = 0
                        
                        foreach ($user in $users) {
                            Write-Log "Processing $($user.username) from bulk list" -Level Info
                            
                            $success = Start-UserOffboarding -Username $user.username -FullAccessUser $user.ForwardingAddress
                            
                            if ($success) {
                                $successCount++
                            }
                            else {
                                $failCount++
                            }
                        }
                        
                        # Summary
                        Write-Log "Bulk processing complete" -Level Info
                        Write-Log "Successfully processed: $successCount" -Level Info
                        if ($failCount -gt 0) {
                            Write-Log "Failed to process: $failCount" -Level Warning
                            Write-Log "See log file for details: $($Script:Config.LogFile)" -Level Info
                        }
                        
                        $OffboardingComplete = $true
                    }
                    elseif ($confirmation -eq "N") {
                        continue
                    }
                }
                
                default {
                    Write-Log "Invalid selection. Please enter 'Single' or 'Bulk'." -Level Warning
                }
            }
        }
        catch {
            Write-Log "Error in offboarding process: $($_.Exception.Message)" -Level Error
            Write-Log "Try Again." -Level Info
        }
    }
    
    # Script completed
    Write-Log "Script completed successfully" -Level Info
    Write-Host "Press any key to exit..."
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
}

# Start the script
Start-OffboardingProcess
