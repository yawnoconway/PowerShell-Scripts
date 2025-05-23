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
                $domain = if ($user.Domain) { $user.Domain } else { $Script:Config.LiteraDomain }
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
                    UPN = "prod-$($user.FirstName).$($user.LastName)@$($Script:Config.LiteraMSDomain)"
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
 _     _ _                   _____       _                         _ _             
| |   (_) |                 |  _  |     | |                       | (_)            
| |    _| |_ ___ _ __ __ _  | | | |_ __ | |__   ___   __ _ _ __ __| |_ _ __   __ _ 
| |   | | __/ _ \ '__/ _` | | | | | '_ \| '_ \ / _ \ / _` | '__/ _` | | '_ \ / _` |
| |___| | ||  __/ | | (_| | \ \_/ / | | | |_) | (_) | (_| | | | (_| | | | | | (_| |
\_____/_|\__\___|_|  \__,_|  \___/|_| |_|_.__/ \___/ \__,_|_|  \__,_|_|_| |_|\__, |
                                                                              __/ |
                                                                             |___/ 
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
                "A" { $Script:Config.LiteraDomain }
                "B" { $Script:Config.OfficeDragonsDomain }
                default { $Script:Config.LiteraDomain }
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
            $parentUPN = Read-Host "Enter the parent UPN (e.g. first.last@litera.com) or leave blank if none"
            
            # Start onboarding process
            $result = Start-ProdAccountOnboarding -FirstName $firstName -LastName $lastName -ParentUPN $parentUPN
            
            # Display results
            if ($result) {
                Write-Host "`nProd account creation completed successfully!" -ForegroundColor Green
                Write-Host "Prod account: prod-$firstName.$lastName@$($Script:Config.LiteraMSDomain)" -ForegroundColor Cyan
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
