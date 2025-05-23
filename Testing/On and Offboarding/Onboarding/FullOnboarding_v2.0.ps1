#Requires -Modules ActiveDirectory, ExchangeOnlineManagement, Microsoft.Graph

<#
.SYNOPSIS
    Complete user onboarding script for AD/M365.
.DESCRIPTION
    This script automates the onboarding process for users by:
    - Creating AD accounts with appropriate attributes
    - Setting random passwords
    - Adding to appropriate security groups
    - Mail-enabling accounts in Exchange Online
    - Setting mailbox retention policies
    - Assigning appropriate licenses
    - Adding to Azure security groups
    - Creating prod accounts if needed
    - Creating service accounts with appropriate settings
.NOTES
    Version: 2.0
    Created: April 24, 2025
    Author: Josh Conway
#>

#-----------------------------
# Configuration
#-----------------------------
$Script:Config = @{
    # Paths
    BulkImportPath            = "$PSScriptRoot\Bulk-Onboarding.csv"

    # Active Directory
    NewUserOU                 = "OU=New,OU=Current,OU=Users,OU=LiteraMS,DC=literams,DC=net"
    UserDomain                = "litera.com"
    SecondaryDomain           = "officeanddragons.com"
    TenantDomain              = "literams.net"

    # ASCII Banner Path
    BannerFile                = "$PSScriptRoot\banner.txt"

    # Logging
    LogFile                   = "$PSScriptRoot\OnboardingLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

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
        @{Name = "ActiveDirectory"; Required = $true },
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

function New-ADUserAccount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FirstName,

        [Parameter(Mandatory = $true)]
        [string]$LastName,

        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [string]$Domain,

        [Parameter(Mandatory = $false)]
        [string]$Description = "",

        [Parameter(Mandatory = $false)]
        [SecureString]$Password = (Get-RandomPassword)
    )

    try {
        # Check if username is over 20 characters and truncate for SAM account name if needed
        $UserSAM = ($Username -replace '(?<=(.{20})).+')
        $DisplayName = "$FirstName $LastName"
        $UPN = "$Username@$Domain"
        $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force

        # Create the user
        $params = @{
            'Name'              = $DisplayName
            'GivenName'         = $FirstName
            'Surname'           = $LastName
            'DisplayName'       = $DisplayName
            'SamAccountName'    = $UserSAM
            'UserPrincipalName' = $UPN
            'Path'              = $Script:Config.NewUserOU
            'AccountPassword'   = $SecurePassword
            'Enabled'           = $true
            'Description'       = $Description
        }

        New-ADUser @params -ErrorAction Stop

        Write-Log "Successfully created AD account for $Username with UPN $UPN"
        return @{
            Success = $true
            Password = $Password
            UserSAM = $UserSAM
            UPN = $UPN
        }
    }
    catch {
        Write-Log "Failed to create AD account for ${Username}: $($_.Exception.Message)" -Level Error
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Add-UserToSecurityGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserSAM,

        [Parameter(Mandatory = $true)]
        [string[]]$Groups
    )

    try {
        foreach ($group in $Groups) {
            Add-ADGroupMember -Identity $group -Members $UserSAM -ErrorAction Stop
            Write-Log "Added $UserSAM to group $group" -NoConsole
        }

        Write-Log "Successfully added $UserSAM to all required security groups"
        return $true
    }
    catch {
        Write-Log "Failed to add $UserSAM to security groups: $($_.Exception.Message)" -Level Error
        return $false
    }
}

#-----------------------------
# Mailbox Functions
#-----------------------------
function Enable-UserMailbox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UPN
    )

    try {
        # Extract username from UPN
        $username = $UPN.Split('@')[0]
        $RRA = "$username@literams.mail.onmicrosoft.com"

        # Enable remote mailbox
        Enable-RemoteMailbox $UPN -RemoteRoutingAddress $RRA -ErrorAction Stop

        Write-Log "Successfully enabled mailbox for $UPN with routing address $RRA"
        return $true
    }
    catch {
        Write-Log "Failed to enable mailbox for ${UPN}: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Set-MailboxRetentionPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UPN
    )

    try {
        # Set retention policy
        Set-Mailbox -Identity $UPN -RetentionPolicy "Litera Mail User Policy" -ErrorAction Stop

        Write-Log "Successfully set retention policy for $UPN"
        return $true
    }
    catch {
        Write-Log "Failed to set retention policy for ${UPN}: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function New-SharedMailbox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UPN,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $false)]
        [string]$ForwardingAddress = ""
    )

    try {
        # Create shared mailbox
        New-Mailbox -Shared -Name $DisplayName -DisplayName $DisplayName -PrimarySmtpAddress $UPN -ErrorAction Stop

        # Hide from GAL
        Set-Mailbox -Identity $UPN -HiddenFromAddressListsEnabled $true -ErrorAction Stop

        # Set forwarding if specified
        if (-not [string]::IsNullOrEmpty($ForwardingAddress)) {
            Set-Mailbox -Identity $UPN -ForwardingAddress $ForwardingAddress -DeliverToMailboxAndForward $true -ErrorAction Stop
            Write-Log "Set forwarding from $UPN to $ForwardingAddress"
        }

        Write-Log "Successfully created shared mailbox for $UPN"
        return $true
    }
    catch {
        Write-Log "Failed to create shared mailbox for ${UPN}: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Add-MailboxPermission {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Mailbox,

        [Parameter(Mandatory = $true)]
        [string]$User
    )

    try {
        # Add full access permission
        Add-MailboxPermission -Identity $Mailbox -User $User -AccessRights FullAccess -InheritanceType All -ErrorAction Stop

        Write-Log "Successfully added full access permission for $User to $Mailbox"
        return $true
    }
    catch {
        Write-Log "Failed to add mailbox permission for ${User} to ${Mailbox}: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Send-TestEmail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Recipient
    )

    try {
        # Send test email
        $subject = "Test Email - Account Creation"
        $body = "This is a test email to verify that the mailbox is working correctly."

        Send-MailMessage -To $Recipient -From $Recipient -Subject $subject -Body $body -SmtpServer "smtp.office365.com" -Port 587 -UseSsl -ErrorAction Stop

        Write-Log "Successfully sent test email to $Recipient"
        return $true
    }
    catch {
        Write-Log "Failed to send test email to ${Recipient}: $($_.Exception.Message)" -Level Error
        return $false
    }
}

#-----------------------------
# License Functions
#-----------------------------
function Add-UserLicense {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UPN,

        [Parameter(Mandatory = $true)]
        [string[]]$Licenses
    )

    try {
        $mguser = Get-MgUser -UserId $UPN -ErrorAction Stop

        foreach ($license in $Licenses) {
            try {
                # Get license SKU ID
                $sku = Get-MgSubscribedSku -All | Where-Object { $_.SkuPartNumber -eq $license }

                if ($sku) {
                    # Assign license
                    Set-MgUserLicense -UserId $mguser.Id -AddLicenses @{SkuId = $sku.SkuId} -RemoveLicenses @() -ErrorAction Stop
                    Write-Log "Successfully assigned license $license to $UPN"
                }
                else {
                    Write-Log "License SKU $license not found" -Level Warning
                }
            }
            catch {
                Write-Log "Failed to assign license $license to ${UPN}: $($_.Exception.Message)" -Level Warning
            }
        }

        return $true
    }
    catch {
        Write-Log "Failed to assign licenses to ${UPN}: $($_.Exception.Message)" -Level Error
        return $false
    }
}

#-----------------------------
# Azure Group Functions
#-----------------------------
function Add-UserToAzureGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UPN,

        [Parameter(Mandatory = $true)]
        [string[]]$Groups
    )

    try {
        $mguser = Get-MgUser -UserId $UPN -ErrorAction Stop

        foreach ($group in $Groups) {
            try {
                # Get group ID
                $mggroup = Get-MgGroup -Filter "displayName eq '$group'" -ErrorAction Stop

                if ($mggroup) {
                    # Add user to group
                    New-MgGroupMember -GroupId $mggroup.Id -DirectoryObjectId $mguser.Id -ErrorAction Stop
                    Write-Log "Added $UPN to Azure group $group" -NoConsole
                }
                else {
                    Write-Log "Azure group $group not found" -Level Warning
                }
            }
            catch {
                Write-Log "Failed to add $UPN to Azure group ${group}: $($_.Exception.Message)" -Level Warning
            }
        }

        Write-Log "Successfully processed Azure group memberships for $UPN"
        return $true
    }
    catch {
        Write-Log "Failed to add $UPN to Azure groups: $($_.Exception.Message)" -Level Error
        return $false
    }
}

#-----------------------------
# Wait for Cloud Account
#-----------------------------
function Wait-ForCloudAccount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UPN,

        [Parameter(Mandatory = $false)]
        [int]$MaxAttempts = 10,

        [Parameter(Mandatory = $false)]
        [int]$DelaySeconds = 30
    )

    Write-Log "Waiting for $UPN to appear in Exchange Online..."

    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            $mailbox = Get-Mailbox -Identity $UPN -ErrorAction SilentlyContinue

            if ($mailbox) {
                Write-Log "Mailbox for $UPN found in Exchange Online after $i attempts"
                return $true
            }

            Write-Log "Attempt $i/${MaxAttempts}: Mailbox for $UPN not found yet, waiting $DelaySeconds seconds..." -NoConsole
            Start-Sleep -Seconds $DelaySeconds
        }
        catch {
            Write-Log "Error checking for mailbox: $($_.Exception.Message)" -Level Warning -NoConsole
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    Write-Log "Mailbox for $UPN not found after $MaxAttempts attempts" -Level Warning
    return $false
}

#-----------------------------
# Employee Onboarding Function
#-----------------------------
function Start-EmployeeOnboarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FirstName,

        [Parameter(Mandatory = $true)]
        [string]$LastName,

        [Parameter(Mandatory = $false)]
        [ValidateSet("AMER", "APAC", "EMEA")]
        [string]$Region = "AMER",

        [Parameter(Mandatory = $false)]
        [ValidateSet("litera.com", "officeanddragons.com")]
        [string]$Domain = "litera.com",

        [Parameter(Mandatory = $false)]
        [ValidateSet("Windows", "Mac")]
        [string]$DeviceType = "Windows",

        [Parameter(Mandatory = $false)]
        [bool]$NeedsGitHub = $false,

        [Parameter(Mandatory = $false)]
        [bool]$NeedsVPN = $false,

        [Parameter(Mandatory = $false)]
        [bool]$NeedsProdAccount = $false
    )

    # Initialize variables
    $Username = "$FirstName.$LastName"
    $Description = "Employee - $Region"
    $Password = Get-RandomPassword

    Write-Log "Starting employee onboarding process for $FirstName $LastName" -Level Info

    # Check if username is over 20 characters
    if ($Username.Length -gt 20) {
        Write-Log "Username $Username is over 20 characters. SAM account name will be truncated." -Level Warning
    }

    # Track success/failure for each step
    $results = @{}

    # Create AD account
    $adResult = New-ADUserAccount -FirstName $FirstName -LastName $LastName -Username $Username -Domain $Domain -Description $Description -Password $Password
    $results["Create AD Account"] = $adResult.Success

    if ($adResult.Success) {
        $UserSAM = $adResult.UserSAM
        $UPN = $adResult.UPN

        # Add to standard security groups
        $standardGroups = @("Intune-General", "SG-Intune-Autopilot-HardwareHash")
        $results["Add to Security Groups"] = Add-UserToSecurityGroups -UserSAM $UserSAM -Groups $standardGroups

        # Enable mailbox
        $results["Enable Mailbox"] = Enable-UserMailbox -UPN $UPN

        # Wait for cloud account
        $cloudAccountExists = Wait-ForCloudAccount -UPN $UPN
        $results["Cloud Account Created"] = $cloudAccountExists

        if ($cloudAccountExists) {
            # Set mailbox retention policy
            $results["Set Retention Policy"] = Set-MailboxRetentionPolicy -UPN $UPN

            # Assign license
            $results["Assign License"] = Add-UserLicense -UPN $UPN -Licenses @("Microsoft 365 E5")

            # Add to Azure security groups based on requirements
            $azureGroups = @()

            if ($DeviceType -eq "Mac") {
                $azureGroups += "SG-SecOps-MacUsers"
            }

            if ($NeedsGitHub) {
                $azureGroups += "SG-Github-Users"
            }

            if ($NeedsVPN) {
                $azureGroups += "SG-P81-Users"
            }

            if ($azureGroups.Count -gt 0) {
                $results["Add to Azure Groups"] = Add-UserToAzureGroups -UPN $UPN -Groups $azureGroups
            }

            # Create prod account if needed
            if ($NeedsProdAccount) {
                $prodResult = Start-ProdAccountOnboarding -FirstName $FirstName -LastName $LastName -ParentUPN $UPN
                $results["Create Prod Account"] = $prodResult
            }
        }
    }

    # Count successes and failures
    $successful = ($results.Values | Where-Object { $_ -eq $true }).Count
    $failed = ($results.Values | Where-Object { $_ -eq $false }).Count
    $total = $results.Count

    # Log summary
    Write-Log "Onboarding summary for ${FirstName} ${LastName}:" -Level Info
    Write-Log "Successful operations: $successful/$total" -Level Info

    if ($failed -gt 0) {
        Write-Log "Failed operations: $failed/$total" -Level Warning
        foreach ($key in $results.Keys) {
            if ($results[$key] -eq $false) {
                Write-Log "- $key" -Level Warning
            }
        }
    }

    # Return the password for display to the user
    return @{
        Success = ($failed -eq 0)
        Password = $Password
        UPN = $UPN
    }
}

#-----------------------------
# Contractor Onboarding Function
#-----------------------------
function Start-ContractorOnboarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FirstName,

        [Parameter(Mandatory = $true)]
        [string]$LastName,

        [Parameter(Mandatory = $false)]
        [ValidateSet("AMER", "APAC", "EMEA")]
        [string]$Region = "AMER",

        [Parameter(Mandatory = $false)]
        [ValidateSet("Windows", "Mac", "W365 VM", "None")]
        [string]$DeviceType = "Windows",

        [Parameter(Mandatory = $false)]
        [bool]$NeedsGitHub = $false,

        [Parameter(Mandatory = $false)]
        [bool]$NeedsVPN = $false
    )

    # Initialize variables
    $Username = "$FirstName.$LastName"
    $Description = "Contractor - $Region"
    $Domain = $Script:Config.UserDomain
    $Password = Get-RandomPassword

    Write-Log "Starting contractor onboarding process for $FirstName $LastName" -Level Info

    # Check if username is over 20 characters
    if ($Username.Length -gt 20) {
        Write-Log "Username $Username is over 20 characters. SAM account name will be truncated." -Level Warning
    }

    # Track success/failure for each step
    $results = @{}

    # Create AD account
    $adResult = New-ADUserAccount -FirstName $FirstName -LastName $LastName -Username $Username -Domain $Domain -Description $Description -Password $Password
    $results["Create AD Account"] = $adResult.Success

    if ($adResult.Success) {
        $UserSAM = $adResult.UserSAM
        $UPN = $adResult.UPN

        # Add to standard security groups
        $standardGroups = @("Intune-General", "SG-Intune-Autopilot-HardwareHash")
        $results["Add to Security Groups"] = Add-UserToSecurityGroups -UserSAM $UserSAM -Groups $standardGroups

        # Enable mailbox
        $results["Enable Mailbox"] = Enable-UserMailbox -UPN $UPN

        # Wait for cloud account
        $cloudAccountExists = Wait-ForCloudAccount -UPN $UPN
        $results["Cloud Account Created"] = $cloudAccountExists

        if ($cloudAccountExists) {
            # Set mailbox retention policy
            $results["Set Retention Policy"] = Set-MailboxRetentionPolicy -UPN $UPN

            # Assign licenses based on device type
            if ($DeviceType -eq "Windows" -or $DeviceType -eq "Mac" -or $DeviceType -eq "W365 VM") {
                $licenses = @("Microsoft 365 E5")

                if ($DeviceType -eq "W365 VM") {
                    $licenses += "Windows 365 Enterprise 4vCPU, 16GB, 128GB"
                }

                $results["Assign License"] = Add-UserLicense -UPN $UPN -Licenses $licenses
            }
            elseif ($DeviceType -eq "None") {
                $results["Assign License"] = Add-UserLicense -UPN $UPN -Licenses @("Office 365 E1", "Enterprise Mobility + Security E3")
            }

            # Add to Azure security groups based on requirements
            $azureGroups = @()

            if ($DeviceType -eq "Mac") {
                $azureGroups += "SG-SecOps-MacUsers"
            }

            if ($NeedsGitHub) {
                $azureGroups += "SG-Github-Users"
            }

            if ($NeedsVPN) {
                $azureGroups += "SG-P81-Users"
            }

            if ($azureGroups.Count -gt 0) {
                $results["Add to Azure Groups"] = Add-UserToAzureGroups -UPN $UPN -Groups $azureGroups
            }
        }
    }

    # Count successes and failures
    $successful = ($results.Values | Where-Object { $_ -eq $true }).Count
    $failed = ($results.Values | Where-Object { $_ -eq $false }).Count
    $total = $results.Count

    # Log summary
    Write-Log "Onboarding summary for ${FirstName} ${LastName}:" -Level Info
    Write-Log "Successful operations: $successful/$total" -Level Info

    if ($failed -gt 0) {
        Write-Log "Failed operations: $failed/$total" -Level Warning
        foreach ($key in $results.Keys) {
            if ($results[$key] -eq $false) {
                Write-Log "- $key" -Level Warning
            }
        }
    }

    # Return the password for display to the user
    return @{
        Success = ($failed -eq 0)
        Password = $Password
        UPN = $UPN
    }
}

#-----------------------------
# Prod Account Onboarding Function
#-----------------------------
function Start-ProdAccountOnboarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FirstName,

        [Parameter(Mandatory = $true)]
        [string]$LastName,

        [Parameter(Mandatory = $false)]
        [string]$ParentUPN = ""
    )

    # Initialize variables
    $ProdFirstName = "prod-$FirstName"
    $ProdDisplayName = "prod-$FirstName $LastName"
    $ProdUsername = "prod-$FirstName.$LastName"
    $ProdUPN = "$ProdUsername@$($Script:Config.TenantDomain)"

    Write-Log "Starting prod account creation for $ProdDisplayName" -Level Info

    # Track success/failure for each step
    $results = @{}

    try {
        # Create user in Azure
        $params = @{
            DisplayName = $ProdDisplayName
            GivenName = $ProdFirstName
            Surname = $LastName
            UserPrincipalName = $ProdUPN
            MailNickname = $ProdUsername
            AccountEnabled = $true
            PasswordProfile = @{
                Password = Get-RandomPassword
                ForceChangePasswordNextSignIn = $false
            }
        }

        New-MgUser @params -ErrorAction Stop
        $results["Create Azure User"] = $true
        Write-Log "Successfully created Azure user $ProdUPN"

        # Wait for the user to be created
        Start-Sleep -Seconds 10

        # Check if user was created successfully
        $mguser = Get-MgUser -UserId $ProdUPN -ErrorAction SilentlyContinue

        if ($mguser) {
            # User was created successfully
            # Hide from GAL
            Set-Mailbox -Identity $ProdUPN -HiddenFromAddressListsEnabled $true -ErrorAction Stop
            $results["Hide from GAL"] = $true

            # Set forwarding if parent UPN is provided
            if (-not [string]::IsNullOrEmpty($ParentUPN)) {
                Set-Mailbox -Identity $ProdUPN -ForwardingAddress $ParentUPN -DeliverToMailboxAndForward $true -ErrorAction Stop
                $results["Set Forwarding"] = $true
                Write-Log "Set forwarding from $ProdUPN to $ParentUPN"
            }

            # Send test email
            $results["Send Test Email"] = Send-TestEmail -Recipient $ProdUPN
        }
        else {
            # User creation failed, create shared mailbox instead
            Write-Log "Azure user creation failed or not found. Creating shared mailbox instead." -Level Warning

            $results["Create Shared Mailbox"] = New-SharedMailbox -UPN $ProdUPN -DisplayName $ProdDisplayName -ForwardingAddress $ParentUPN

            # Send test email
            $results["Send Test Email"] = Send-TestEmail -Recipient $ProdUPN
        }
    }
    catch {
        Write-Log "Failed to create prod account for ${ProdUsername}: $($_.Exception.Message)" -Level Error
        return $false
    }

    # Count successes and failures
    $successful = ($results.Values | Where-Object { $_ -eq $true }).Count
    $failed = ($results.Values | Where-Object { $_ -eq $false }).Count
    $total = $results.Count

    # Log summary
    Write-Log "Prod account creation summary for ${ProdDisplayName}:" -Level Info
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
# Service Account Onboarding Function
#-----------------------------
function Start-ServiceAccountOnboarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FirstName,

        [Parameter(Mandatory = $true)]
        [string]$LastName,

        [Parameter(Mandatory = $false)]
        [bool]$NeedsMail = $false,

        [Parameter(Mandatory = $false)]
        [string]$FullAccessUser = ""
    )

    # Initialize variables
    $SvcFirstName = "svc-$FirstName"
    $SvcDisplayName = "svc-$FirstName $LastName"
    $SvcUsername = "svc-$FirstName.$LastName"
    $SvcUPN = "$SvcUsername@$($Script:Config.UserDomain)"

    Write-Log "Starting service account creation for $SvcDisplayName" -Level Info

    # Track success/failure for each step
    $results = @{}

    try {
        # Create user in Azure
        $params = @{
            DisplayName = $SvcDisplayName
            GivenName = $SvcFirstName
            Surname = $LastName
            UserPrincipalName = $SvcUPN
            MailNickname = $SvcUsername
            AccountEnabled = $true
            PasswordProfile = @{
                Password = Get-RandomPassword
                ForceChangePasswordNextSignIn = $false
            }
        }

        New-MgUser @params -ErrorAction Stop
        $results["Create Azure User"] = $true
        Write-Log "Successfully created Azure user $SvcUPN"

        # Wait for the user to be created
        Start-Sleep -Seconds 10

        # If mail is needed
        if ($NeedsMail) {
            # Assign Exchange Online license
            $results["Assign License"] = Add-UserLicense -UPN $SvcUPN -Licenses @("Exchange Online (Plan 1)")

            # Wait for mailbox to be created
            $mailboxExists = Wait-ForCloudAccount -UPN $SvcUPN
            $results["Mailbox Created"] = $mailboxExists

            # Add full access permission if specified
            if ($mailboxExists -and -not [string]::IsNullOrEmpty($FullAccessUser)) {
                $results["Add Full Access"] = Add-MailboxPermission -Mailbox $SvcUPN -User $FullAccessUser
            }
        }
    }
    catch {
        Write-Log "Failed to create service account for ${SvcUsername}: $($_.Exception.Message)" -Level Error
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }

    # Count successes and failures
    $successful = ($results.Values | Where-Object { $_ -eq $true }).Count
    $failed = ($results.Values | Where-Object { $_ -eq $false }).Count
    $total = $results.Count

    # Log summary
    Write-Log "Service account creation summary for ${SvcDisplayName}:" -Level Info
    Write-Log "Successful operations: $successful/$total" -Level Info

    if ($failed -gt 0) {
        Write-Log "Failed operations: $failed/$total" -Level Warning
        foreach ($key in $results.Keys) {
            if ($results[$key] -eq $false) {
                Write-Log "- $key" -Level Warning
            }
        }
    }

    return @{
        Success = ($failed -eq 0)
        UPN = $SvcUPN
    }
}
#-----------------------------
# CSV Processing Functions
#-----------------------------
function Import-BulkUsers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CsvPath
    )

    try {
        # Check if file exists
        if (-not (Test-Path -Path $CsvPath)) {
            Write-Log "CSV file not found: $CsvPath" -Level Error
            return $null
        }

        # Import CSV
        $users = Import-Csv -Path $CsvPath -ErrorAction Stop

        # Validate CSV structure
        if ($users.Count -eq 0) {
            Write-Log "CSV file is empty: $CsvPath" -Level Error
            return $null
        }

        # Check for required columns
        $requiredColumns = @("FirstName", "LastName", "UserType")
        $missingColumns = $requiredColumns | Where-Object { $users[0] | Get-Member -Name $_ -MemberType NoteProperty -ErrorAction SilentlyContinue -OutVariable result; $result.Count -eq 0 }

        if ($missingColumns.Count -gt 0) {
            Write-Log "CSV file is missing required columns: $($missingColumns -join ', ')" -Level Error
            return $null
        }

        Write-Log "Successfully imported $($users.Count) users from CSV" -Level Info
        return $users
    }
    catch {
        Write-Log "Failed to import users from CSV: $($_.Exception.Message)" -Level Error
        return $null
    }
}

function Start-BulkUsers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Users,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Employee", "Contractor", "ProdAccount", "ServiceAccount")]
        [string]$UserType
    )

    $results = @()

    foreach ($user in $Users) {
        Write-Log "Processing user: $($user.FirstName) $($user.LastName)" -Level Info

        # Skip if user type doesn't match
        if ($user.UserType -ne $UserType) {
            Write-Log "Skipping user $($user.FirstName) $($user.LastName) - User type mismatch" -Level Warning
            continue
        }

        $result = $null

        # Process based on user type
        switch ($UserType) {
            "Employee" {
                # Set default values if not specified
                $region = if ($user.Region) { $user.Region } else { "AMER" }
                $domain = if ($user.Domain) { $user.Domain } else { $Script:Config.UserDomain }
                $deviceType = if ($user.DeviceType) { $user.DeviceType } else { "Windows" }
                $needsGitHub = if ($user.NeedsGitHub -eq "Y") { $true } else { $false }
                $needsVPN = if ($user.NeedsVPN -eq "Y") { $true } else { $false }
                $needsProdAccount = if ($user.NeedsProdAccount -eq "Y") { $true } else { $false }

                # Start onboarding process
                $result = Start-EmployeeOnboarding -FirstName $user.FirstName -LastName $user.LastName -Region $region -Domain $domain -DeviceType $deviceType -NeedsGitHub $needsGitHub -NeedsVPN $needsVPN -NeedsProdAccount $needsProdAccount
            }
            "Contractor" {
                # Set default values if not specified
                $region = if ($user.Region) { $user.Region } else { "AMER" }
                $deviceType = if ($user.DeviceType) { $user.DeviceType } else { "Windows" }
                $needsGitHub = if ($user.NeedsGitHub -eq "Y") { $true } else { $false }
                $needsVPN = if ($user.NeedsVPN -eq "Y") { $true } else { $false }

                # Start onboarding process
                $result = Start-ContractorOnboarding -FirstName $user.FirstName -LastName $user.LastName -Region $region -DeviceType $deviceType -NeedsGitHub $needsGitHub -NeedsVPN $needsVPN
            }
            "ProdAccount" {
                # Set default values if not specified
                $parentUPN = if ($user.ParentUPN) { $user.ParentUPN } else { "" }

                # Start onboarding process
                $prodResult = Start-ProdAccountOnboarding -FirstName $user.FirstName -LastName $user.LastName -ParentUPN $parentUPN

                $result = @{
                    Success = $prodResult
                    UPN = "prod-$($user.FirstName).$($user.LastName)@$($Script:Config.TenantDomain)"
                }
            }
            "ServiceAccount" {
                # Set default values if not specified
                $needsMail = if ($user.NeedsMail -eq "Y") { $true } else { $false }
                $fullAccessUser = if ($user.FullAccessUser) { $user.FullAccessUser } else { "" }

                # Start onboarding process
                $result = Start-ServiceAccountOnboarding -FirstName $user.FirstName -LastName $user.LastName -NeedsMail $needsMail -FullAccessUser $fullAccessUser
            }
        }

        # Add to results
        if ($result) {
            $resultObj = [PSCustomObject]@{
                FirstName = $user.FirstName
                LastName = $user.LastName
                UserType = $UserType
                UPN = $result.UPN
                Success = $result.Success
                Password = $result.Password
            }

            $results += $resultObj
        }
    }

    return $results
}

#-----------------------------
# Banner and Help Functions
#-----------------------------
function Show-Banner {
    [CmdletBinding()]
    param()

    $bannerText = @"
   __  __                                                                     
  / / / /_______  _____                                                       
 / / / / ___/ _ \/ ___/                                                       
/ /_/ (__  )  __/ /                                                           
\____/____/\___/_/                        ___                     ___         
  / __ \____  / /_  ____  ____ __________/ (_)___  ____ _        |__ \    ___ 
 / / / / __ \/ __ \/ __ \/ __ `/ ___/ __  / / __ \/ __ `/   _  __ _/ /   / _ \
/ /_/ / / / / /_/ / /_/ / /_/ / /  / /_/ / / / / / /_/ /   | |/ / __/   / // /
\____/_/ /_/_.___/\____/\__,_/_/   \__,_/_/_/ /_/\__, /    |___/____/(_)\___/ 
                                                /____/                        
"@

    Write-Host $bannerText -ForegroundColor Cyan
    Write-Host "User Onboarding Script v1.0" -ForegroundColor Green
    Write-Host "Created: April 24, 2025" -ForegroundColor Green
    Write-Host "Author: Devin AI" -ForegroundColor Green
    Write-Host "--------------------------------------------------------------" -ForegroundColor White
}

function Show-Help {
    [CmdletBinding()]
    param()

    Write-Host "`nUser Onboarding Script Help" -ForegroundColor Yellow
    Write-Host "-------------------------" -ForegroundColor Yellow
    Write-Host "This script automates the onboarding process for different user types:" -ForegroundColor White
    Write-Host "1. Employee - Regular employees with standard access" -ForegroundColor White
    Write-Host "2. Contractor - External contractors with customized access" -ForegroundColor White
    Write-Host "3. Prod Account - Production accounts for specific services" -ForegroundColor White
    Write-Host "4. Service Account - Service accounts for automated processes" -ForegroundColor White
    Write-Host "`nThe script can process single users or bulk users via CSV." -ForegroundColor White
    Write-Host "`nCSV Format for Bulk Processing:" -ForegroundColor Yellow
    Write-Host "For Employee users:" -ForegroundColor White
    Write-Host "FirstName,LastName,UserType,Region,Domain,DeviceType,NeedsGitHub,NeedsVPN,NeedsProdAccount" -ForegroundColor Gray
    Write-Host "John,Doe,Employee,AMER,litera.com,Windows,Y,Y,N" -ForegroundColor Gray
    Write-Host "`nFor Contractor users:" -ForegroundColor White
    Write-Host "FirstName,LastName,UserType,Region,DeviceType,NeedsGitHub,NeedsVPN" -ForegroundColor Gray
    Write-Host "Jane,Smith,Contractor,EMEA,Mac,N,Y" -ForegroundColor Gray
    Write-Host "`nFor Prod Account users:" -ForegroundColor White
    Write-Host "FirstName,LastName,UserType,ParentUPN" -ForegroundColor Gray
    Write-Host "John,Doe,ProdAccount,john.doe@litera.com" -ForegroundColor Gray
    Write-Host "`nFor Service Account users:" -ForegroundColor White
    Write-Host "FirstName,LastName,UserType,NeedsMail,FullAccessUser" -ForegroundColor Gray
    Write-Host "App,Auth,ServiceAccount,Y,admin@litera.com" -ForegroundColor Gray
    Write-Host "`nLog files are stored in the script directory." -ForegroundColor White
}

#-----------------------------
# Main Script Section
#-----------------------------
function Get-UserTypeSelection {
    [CmdletBinding()]
    param()

    Write-Host "`nSelect the user type to onboard:" -ForegroundColor Green
    Write-Host "1. Employee" -ForegroundColor White
    Write-Host "2. Contractor" -ForegroundColor White
    Write-Host "3. Prod Account" -ForegroundColor White
    Write-Host "4. Service Account" -ForegroundColor White

    $choice = Read-Host "Enter your choice (1-4)"

    switch ($choice) {
        "1" { return "Employee" }
        "2" { return "Contractor" }
        "3" { return "ProdAccount" }
        "4" { return "ServiceAccount" }
        default {
            Write-Log "Invalid user type selection. Please enter a number between 1 and 4." -Level Warning
            return Get-UserTypeSelection
        }
    }
}

function Get-ProcessingTypeSelection {
    [CmdletBinding()]
    param()

    Write-Host "`nSelect the processing type:" -ForegroundColor Green
    Write-Host "1. Single User" -ForegroundColor White
    Write-Host "2. Bulk Users (via CSV)" -ForegroundColor White

    $choice = Read-Host "Enter your choice (1-2)"

    switch ($choice) {
        "1" { return "Single" }
        "2" { return "Bulk" }
        default {
            Write-Log "Invalid processing type selection. Please enter 1 or 2." -Level Warning
            return Get-ProcessingTypeSelection
        }
    }
}

function Start-SingleUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Employee", "Contractor", "ProdAccount", "ServiceAccount")]
        [string]$UserType
    )

    switch ($UserType) {
        "Employee" {
            # Get employee information
            $firstName = Read-Host "Enter the first name"
            $lastName = Read-Host "Enter the last name"

            # Region selection
            Write-Host "`nSelect the region:" -ForegroundColor Green
            Write-Host "A. AMER" -ForegroundColor White
            Write-Host "B. APAC" -ForegroundColor White
            Write-Host "C. EMEA" -ForegroundColor White
            $regionChoice = Read-Host "Enter your choice (A-C)"

            $region = switch ($regionChoice) {
                "A" { "AMER" }
                "B" { "APAC" }
                "C" { "EMEA" }
                default { "AMER" }
            }

            # Domain selection
            Write-Host "`nSelect the domain:" -ForegroundColor Green
            Write-Host "A. litera.com" -ForegroundColor White
            Write-Host "B. officeanddragons.com" -ForegroundColor White
            $domainChoice = Read-Host "Enter your choice (A-B)"

            $domain = switch ($domainChoice) {
                "A" { $Script:Config.UserDomain }
                "B" { $Script:Config.SecondaryDomain }
                default { $Script:Config.UserDomain }
            }

            # Device type selection
            Write-Host "`nSelect the device type:" -ForegroundColor Green
            Write-Host "A. Windows" -ForegroundColor White
            Write-Host "B. Mac" -ForegroundColor White
            $deviceChoice = Read-Host "Enter your choice (A-B)"

            $deviceType = switch ($deviceChoice) {
                "A" { "Windows" }
                "B" { "Mac" }
                default { "Windows" }
            }

            # GitHub access
            $githubChoice = Read-Host "Does the user need basic GitHub access? (Y/N)"
            $needsGitHub = $githubChoice -eq "Y"

            # VPN access
            $vpnChoice = Read-Host "Does the user need VPN access? (Y/N)"
            $needsVPN = $vpnChoice -eq "Y"

            # Prod account
            $prodChoice = Read-Host "Does the user need a prod account? (Y/N)"
            $needsProdAccount = $prodChoice -eq "Y"

            # Check username length
            $username = "$firstName.$lastName"
            if ($username.Length -gt 20) {
                Write-Host "Note: Username $username is over 20 characters. SAM account name will be truncated." -ForegroundColor Yellow
            }

            # Start onboarding process
            $result = Start-EmployeeOnboarding -FirstName $firstName -LastName $lastName -Region $region -Domain $domain -DeviceType $deviceType -NeedsGitHub $needsGitHub -NeedsVPN $needsVPN -NeedsProdAccount $needsProdAccount

            # Display results
            if ($result.Success) {
                Write-Host "`nEmployee onboarding completed successfully!" -ForegroundColor Green
                Write-Host "Username: $($result.UPN)" -ForegroundColor Cyan
                Write-Host "Password: $($result.Password)" -ForegroundColor Cyan
                Write-Host "Please provide these credentials to the user." -ForegroundColor Cyan
            }
            else {
                Write-Host "`nEmployee onboarding completed with errors. Please check the log file for details." -ForegroundColor Red
                Write-Host "Log file: $($Script:Config.LogFile)" -ForegroundColor Yellow
            }
        }
        "Contractor" {
            # Get contractor information
            $firstName = Read-Host "Enter the first name"
            $lastName = Read-Host "Enter the last name"

            # Region selection
            Write-Host "`nSelect the region:" -ForegroundColor Green
            Write-Host "A. AMER" -ForegroundColor White
            Write-Host "B. APAC" -ForegroundColor White
            Write-Host "C. EMEA" -ForegroundColor White
            $regionChoice = Read-Host "Enter your choice (A-C)"

            $region = switch ($regionChoice) {
                "A" { "AMER" }
                "B" { "APAC" }
                "C" { "EMEA" }
                default { "AMER" }
            }

            # Device type selection
            Write-Host "`nSelect the device type:" -ForegroundColor Green
            Write-Host "A. Windows" -ForegroundColor White
            Write-Host "B. Mac" -ForegroundColor White
            Write-Host "C. W365 VM" -ForegroundColor White
            Write-Host "D. None" -ForegroundColor White
            $deviceChoice = Read-Host "Enter your choice (A-D)"

            $deviceType = switch ($deviceChoice) {
                "A" { "Windows" }
                "B" { "Mac" }
                "C" { "W365 VM" }
                "D" { "None" }
                default { "Windows" }
            }

            # GitHub access
            $githubChoice = Read-Host "Does the user need basic GitHub access? (Y/N)"
            $needsGitHub = $githubChoice -eq "Y"

            # VPN access
            $vpnChoice = Read-Host "Does the user need VPN access? (Y/N)"
            $needsVPN = $vpnChoice -eq "Y"

            # Check username length
            $username = "$firstName.$lastName"
            if ($username.Length -gt 20) {
                Write-Host "Note: Username $username is over 20 characters. SAM account name will be truncated." -ForegroundColor Yellow
            }

            # Start onboarding process
            $result = Start-ContractorOnboarding -FirstName $firstName -LastName $lastName -Region $region -DeviceType $deviceType -NeedsGitHub $needsGitHub -NeedsVPN $needsVPN

            # Display results
            if ($result.Success) {
                Write-Host "`nContractor onboarding completed successfully!" -ForegroundColor Green
                Write-Host "Username: $($result.UPN)" -ForegroundColor Cyan
                Write-Host "Password: $($result.Password)" -ForegroundColor Cyan
                Write-Host "Please provide these credentials to the user." -ForegroundColor Cyan
            }
            else {
                Write-Host "`nContractor onboarding completed with errors. Please check the log file for details." -ForegroundColor Red
                Write-Host "Log file: $($Script:Config.LogFile)" -ForegroundColor Yellow
            }
        }
        "ProdAccount" {
            # Get prod account information
            $firstName = Read-Host "Enter the first name"
            $lastName = Read-Host "Enter the last name"

            # Parent UPN
            $parentUPN = Read-Host "Enter the parent UPN (e.g. first.last@domain.com) or leave blank if none"

            # Start onboarding process
            $result = Start-ProdAccountOnboarding -FirstName $firstName -LastName $lastName -ParentUPN $parentUPN

            # Display results
            if ($result) {
                Write-Host "`nProd account creation completed successfully!" -ForegroundColor Green
                Write-Host "Prod account: prod-$firstName.$lastName@$($Script:Config.TenantDomain)" -ForegroundColor Cyan
            }
            else {
                Write-Host "`nProd account creation completed with errors. Please check the log file for details." -ForegroundColor Red
                Write-Host "Log file: $($Script:Config.LogFile)" -ForegroundColor Yellow
            }
        }
        "ServiceAccount" {
            # Get service account information
            $firstName = Read-Host "Enter the first name"
            $lastName = Read-Host "Enter the last name"

            # Mail needed
            $mailChoice = Read-Host "Does the service account need mail? (Y/N)"
            $needsMail = $mailChoice -eq "Y"

            # Full access user
            $fullAccessUser = ""
            if ($needsMail) {
                $fullAccessUser = Read-Host "Enter the UPN of the user who should have Full Access to the mailbox (leave blank if none)"
            }

            # Start onboarding process
            $result = Start-ServiceAccountOnboarding -FirstName $firstName -LastName $lastName -NeedsMail $needsMail -FullAccessUser $fullAccessUser

            # Display results
            if ($result.Success) {
                Write-Host "`nService account creation completed successfully!" -ForegroundColor Green
                Write-Host "Service account: $($result.UPN)" -ForegroundColor Cyan
            }
            else {
                Write-Host "`nService account creation completed with errors. Please check the log file for details." -ForegroundColor Red
                Write-Host "Log file: $($Script:Config.LogFile)" -ForegroundColor Yellow
            }
        }
    }
}

function Start-OnboardingProcess {
    [CmdletBinding()]
    param()

    # Show banner
    Show-Banner

    # Initialize modules and connections
    try {
        Initialize-RequiredModules
        Connect-RequiredServices
    }
    catch {
        Write-Log "Failed to initialize required modules or services: $($_.Exception.Message)" -Level Error
        Write-Host "Failed to initialize required modules or services: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please ensure you have the necessary permissions and modules installed." -ForegroundColor Yellow
        return
    }

    # Main onboarding loop
    $OnboardingComplete = $false

    while (-not $OnboardingComplete) {
        try {
            # Interactive user type and processing selection
            $userType = Get-UserTypeSelection
            $processingType = Get-ProcessingTypeSelection

            # Process users based on type and processing method
            switch ($processingType) {
                "Single" {
                    Start-SingleUser -UserType $userType
                }
                "Bulk" {
                    # Process bulk users
                    $csvPath = Read-Host "Enter the path to the CSV file (default: $($Script:Config.BulkImportPath))"

                    if ([string]::IsNullOrEmpty($csvPath)) {
                        $csvPath = $Script:Config.BulkImportPath
                    }

                    # Import users from CSV
                    $users = Import-BulkUsers -CsvPath $csvPath

                    if ($null -eq $users) {
                        Write-Host "Failed to import users from CSV. Please check the file path and format." -ForegroundColor Red
                        continue
                    }

                    # Process users
                    $results = Start-BulkUsers -Users $users -UserType $userType

                    # Display results
                    Write-Host "`nBulk processing completed!" -ForegroundColor Green
                    Write-Host "Successfully processed: $($results.Count)" -ForegroundColor Cyan
                    Write-Host "See log file for details: $($Script:Config.LogFile)" -ForegroundColor Cyan

                    # Export results to CSV
                    $resultsPath = "$PSScriptRoot\OnboardingResults_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                    $results | Export-Csv -Path $resultsPath -NoTypeInformation
                    Write-Host "Results exported to: $resultsPath" -ForegroundColor Cyan
                }
                default {
                    Write-Log "Invalid processing type. Please enter 'Single' or 'Bulk'." -Level Warning
                    continue
                }
            }

            # Ask if user wants to continue
            $continueChoice = Read-Host "`nDo you want to onboard another user? (Y/N)"
            $OnboardingComplete = $continueChoice -ne "Y"
        }
        catch {
            Write-Log "Error in onboarding process: $($_.Exception.Message)" -Level Error
            Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red

            $continueChoice = Read-Host "`nDo you want to try again? (Y/N)"
            $OnboardingComplete = $continueChoice -ne "Y"
        }
    }

    Write-Log "Onboarding process completed" -Level Info
    Write-Host "`nOnboarding process completed. Thank you for using the User Onboarding Script!" -ForegroundColor Green
}

# Execute the script
Start-OnboardingProcess
