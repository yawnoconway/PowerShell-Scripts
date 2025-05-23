<#
 
This script terminates a users Active Directory account following the current User Termination Process.
It gathers AD and Mailbox information prior to making any changes and saves the settings to a text file.
Upon gathering and saving the information, the steps that it takes are:

	1. Remove ActiveSync device memberships or send Remote Wipe to them
	2. Disable the AD Account
	3. Edit the user description field to YYYYMMDD-reason-disabler format
	4. Remove user from all security and distribution groups
	5. Disable Out of Office messages
	6. Disable Email Address Policy
	7. Hide from Exchange Address Lists
	8. Set Mail forwarding (if wanted)
	9. Set Full Mailbox Access permissions (if wanted)
	10. Queue mailbox to move to terminated users mailbox
	11. Move AD Account to Inactive Users OU
	
Upon completing these changes, the script forces AD replication and then rechecks the changed settings and 
creates a report of those settings and emails them.	
#>

### Variables to change
$TerminatedUsersOU = "OU=Disabled,OU=Users,OU=LiteraMS,DC=literams,DC=net" # OU to move AD accounts
$OutputFolder = "\\domain.com\files\Departments\IT\Infrastructure\AD User Terminations\Reports\" # Directory where to save the output files to
$TermMDB = "TerminatedUsers"
$SMTPServer = "relay.domain.com"
$EmailFrom = "UserTermination@domain.com"
$EveryEmailTo = "user@domain.com"

# Import AD Module and set up Exchange Powershell Session Connections
import-module activedirectory

if ($null -eq $ExchangeSession){
$ExchangeSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://CASSERVER1/PowerShell/
import-pssession $ExchangeSession

	if ($Null -eq $ExchangeSession) {$ExchangeSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://CASSERVER2/PowerShell/
		import-pssession $ExchangeSession -allowclobber
	}

}
###

# No need to change this section
$Date = get-date -format yyyyMMdd # Sets date variable in 20151007 format
$Time = get-date -format hh.mm.ss # Sets time variable in 10.15.33 (Hour.Minute.Second) format
$RanAs = [Environment]::UserName
$TestFile = "$Date-$Time-TestWrite.txt"
$RanAsMB = Get-Mailbox -Identity $RanAs
$RanAsEmail = $RanAsMB.PrimarySmtpAddress
if ($Null -eq $RanAsEmail) {$RanAsEmail = "me@domain.com"} #This is there because I run my privileged stuff as an account other than my normal user account and my admin account doesn't have an email address
$EmailTo = @($EveryEmailTo,$RanAsEmail)

Clear #clear screen

# This section verifies that the output folder exists and that you can write to it and exits if it cannot
# Output files contain the AD User information and Group Memberships prior to making any changes
If (Test-Path $OutputFolder)
	{
	
	}
	Else
	{
	Read-Host "Output Path Doesn't Exist.  Press Enter to Exit."
	Exit
	}
	
If (Test-Path $OutputFolder$TestFile)
	{
	Remove-Item $OutputFolder$TestFile
	}
	
"$Date-$Time" > $OutputFolder$TestFile

If (Test-Path $OutputFolder$TestFile)
	{
	Remove-Item $OutputFolder$TestFile
	}
	Else
	{
	Read-Host "Unable to Write to Output Directory.  Press Enter to Exit."
	Exit
	}


### Ask for the user to terminate and gather information about the user

do {
    try {
        $UserOK = $true
        $SAMAccountName = Read-host "Enter the SAMAccountName of the user that you want to terminate"
		$ADUser = get-aduser $SAMAccountName -Properties *
        } # end try
    catch {
	$UserOK = $false
	"Invalid SAMAccountName"
	}
	} # end do 
until (($null -ne $ADUser) -and $UserOK)

$ADUser = Get-ADUser $SAMAccountName -Properties * # Gathers ALL AD account info for the user and stores it in a variable
$DN = $ADUser.DistinguishedName # Sets variable for DistinguishedName of user
$CN = $ADUser.CanonicalName # Sets variable for CanonicalName of the user
$SAMAccountName = $ADuser.SAMAccountName

# Grab info for the description field	
$TicketNumber = Read-Host "Ticket number or reason that you are disabling the account."

# Get Email Forwarding Information
$result = @()
$title = " "
$message = "Do you want to set email forwarding to another user?"
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
    "Set email forwarding to another user."
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
    "Skips this step."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$result = $host.ui.PromptForChoice($title, $message, $options, 1) 

switch ($result)
    {
        0 {" "}
        1 {" "}
    }

If ($result -eq 0)
	{
	do {
    try {
        $UserOK = $true
        $ForwardTo = Read-host "Enter the SAMAccountName of the user that you want to forward email to"
		$ForwardADInfo = get-aduser $ForwardTo -Properties *
		$ForwardToDN = ($ForwardADInfo).DistinguishedName
		$ForwardToCN = ($ForwardADInfo).CanonicalName
        } # end try
    catch {
	$UserOK = $false
	"Invalid SAMAccountName"
	}
	} # end do 
until (($null -ne $ForwardADInfo) -and $UserOK)

	}
	
If ($result -eq 1)
	{
	
	}
	
# Get Full Access Permissions user to add
$result = @()
$title = " "
$message = "Do you want to grant Full Mailbox access to anyone?"
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
    "Grant Full access permissions to another user."
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
    "Skips this step."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$result = $host.ui.PromptForChoice($title, $message, $options, 1) 

switch ($result)
    {
        0 {" "}
        1 {" "}
    }

If ($result -eq 0)
	{
	do {
    try {
        $UserOK = $true
        $FullAccessTo = Read-host "Enter the SAMAccountName of the user that you want to grant full Mailbox permissions to"
		$FullAccessInfo = get-aduser $FullAccessTo -Properties *
		$FullAccesstoDN = ($FullAccessInfo).DistinguishedName
		$FullAccesstoCN = ($FullAccessInfo).CanonicalName
        } # end try
    catch {
	$UserOK = $false
	"Invalid SAMAccountName"
	}
	} # end do 
until (($null -ne $FullAccessInfo) -and $UserOK)

	}
	
If ($result -eq 1)
	{
	
	}

# Getting ActiveSync Device Information
$ActiveSyncDevices = Get-ActiveSyncDevice -ResultSize unlimited | Where {$_.Identity -like "*$CN*"}
	
# Give a last chance to exit script
Clear
Write-Host "This is the user that you selected:"
Write-Host " "
Write-Host "SAMAccountName:" $SAMAccountName
Write-Host "Name:" ($ADUser).Name
Write-Host "CanonicalName:" $CN
Write-Host "ProxyAddresses:" ($ADUser).proxyAddresses
Write-Host " "
if ($Null -eq $ActiveSyncDevices) {Write-Host "There are no ActiveSync device memberships for $SAMAccountName."}
if ($Null -ne $ActiveSyncDevices) {Write-Host "There are ActiveSync device memberships for $SAMAccountName.  You will pick whether to remove them or send a wipe signal."}
Write-Host "The account $SAMAccountName will be disabled"
Write-Host "The user description field will be set to $Date-$TicketNumber-$RanAs"
Write-Host "The user will be removed from all security and distribution groups"
Write-Host "The AD account will be moved to $TerminatedUsersOU"
Write-Host "The account will be hidden from all address lists"
Write-Host "Out of Office messages will be disabled and removed"
if ($null -eq $forwardto) {write-host "You've chosen not to forward email"}
if ($null -ne $forwardto) {write-host "Email will be forwarded to $ForwardToCN"}
if ($null -eq $fullaccessto) {write-host "You've chosen to not grant anyone Full Mailbox Access permissions"}
if ($null -ne $fullaccessto) {write-host "Full Mailbox Access permissions will be granted to $FullAccessToCN"}

$result = @()
$title = " "
$message = "Do you want to continue?"
Write-Host " "
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
    "Begins the account termination process."
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
    "Exits the script and makes no changes to the account."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$result = $host.ui.PromptForChoice($title, $message, $options, 1) 

switch ($result)
    {
        0 {"Continuing."}
        1 {"Exiting without making changes."}
    }

If ($result -eq 0)
	{
	
	}
	
If ($result -eq 1)
	{
	Exit
	}

# Setup Output file names
$OutputFolder2 = "$OutputFolder$SamAccountname-$date-$time\"
New-Item -ItemType Directory -Path $OutputFolder2 | Out-Null
$ADUserInfoFile = $OutputFolder2+"Before-ADUserInfo.txt"
$SecGroupMembershipsFile = $OutputFolder2+"Before-SecurityGroupMemberships.txt"
$DistGroupMembershipsFile = $OutputFolder2+"Before-DistributionGroupMemberships.txt"
$ActiveSyncDevicesFile = $OutputFolder2+"Before-ActiveSyncInfo.txt"
$OutOfOfficeFile = $OutputFolder2+"Before-OutOfOfficeInfo.txt"	
	
### Gathering information and saving settings to output files
# Saving user settings to output files
Write-Host " "
Write-Host "Saving Account information to $OutputFolder2"
$ADUser | Out-File $ADUserInfoFile # Outputs all AD account information to a txt file before making any modifications

# Build a list of all group that this user belongs to
$AllGroups = Get-ADGroup -Filter * -Properties * 
$SecGroups = $AllGroups | Where {$_.GroupCategory -eq "Security"} | Where {$_.Members -like $DN} # Sets variable containing all security groups that the user is in
$SecGroups | Select Name | Sort Name | Out-File $SecGroupMembershipsFile # Outputs all Security Group Memberships to a txt file before making and modifications
$DistGroups = $AllGroups | Where {$_.GroupCategory -eq "Distribution"} | Where {$_.Members -like $DN} # Sets variable containing all distribution groups that the user is in
$DistGroups | Select Name | Sort Name | Out-File $DistGroupMembershipsFile # Outputs all Distribution Group Memberships to a txt file before making and modifications

# Getting ActiveSync Device Information
if ($Null -ne $ActiveSyncDevices) {$ActiveSyncDevices | Out-File $ActiveSyncDevicesFile}

# Getting Out of Office Settings
$OutOfOffice = Get-MailboxAutoReplyConfiguration -Identity $DN
$OutOfOffice | Out-File $OutOfOfficeFile

### Beginning Modifications
# Removing ActiveSync Device Partnerships if any exist

if ($Null -ne $ActiveSyncDevices){
$result = @()
$title = " "
$message = "Do you want to remove ActiveSync device partnerships or perform a remote wipe of them?"
Write-Host " "
$remove = New-Object System.Management.Automation.Host.ChoiceDescription "&Remove", `
    "Removes the ActiveSync device partnership(s) for $SAMAccountName."

$wipe = New-Object System.Management.Automation.Host.ChoiceDescription "&Wipe", `
    "Performs a remote wipe of the ActiveSync device(s) configured for $SAMAccountName."

$options = [System.Management.Automation.Host.ChoiceDescription[]]($remove, $wipe)

$result = $host.ui.PromptForChoice($title, $message, $options, 0) 

switch ($result)
    {
        0 {"Removing ActiveSync Membership."}
        1 {"Sending Remote Wipe Signal."}
    }

If ($result -eq 0)
	{
		foreach ($ActiveSyncDevice in $ActiveSyncDevices){ 
			Remove-ActiveSyncDevice -Identity $ActiveSyncDevice.DistinguishedName -Confirm:$False
			Write-Host "ActiveSync Memberships Removed."
		}
	}
	
If ($result -eq 1)
	{
		foreach ($ActiveSyncDevice in $ActiveSyncDevices){
			Clear-ActiveSyncDevice -Identity $ActiveSyncDevice.DistinguishedName -Confirm:$False 
			Write-Host "Remote Wipe Message Sent."
		}
	}
}
	
# Disabling User Account
Write-Host " "
Write-Host "Disabling $SAMAccountName"
Set-ADUser $SAMAccountName -Enabled $False  # Disables the account

# Changing User Description
Write-Host " "
Write-Host "Changing AD account description"
Set-ADUser $SAMAccountName -Description $Date-$TicketNumber-$RanAs

# Removing user from all groups
Write-Host " "
Write-Host "Removing $SAMAccountName from all groups"

if ($null -ne $Secgroups){
	Foreach ($SecGroup in $SecGroups)
		{
		Remove-ADGroupMember -Identity $SecGroup.DistinguishedName -Members $DN -Confirm:$false
		}
}
		
if ($null -ne $DistGroups){
	Foreach ($DistGroup in $DistGroups)	
		{
		Remove-DistributionGroupMember -Identity $DistGroup.name -Member $DN -Confirm:$False
		}
}

Start-Sleep 10

#Catch Funky Groups 
$AllGroups = Get-ADGroup -Filter * -Properties * 
$AllADGroups = $AllGroups | Where {$_.Members -like $DN}

if ($null -ne $AllADGroups){
	Foreach ($AllADGroup in $AllADGroups)	
		{
		Remove-ADGroupMember -Identity $AllADGroup.DistinguishedName -Members $DN -Confirm:$false
		}
}


# Disable Out of Office messages and remove set messages 
Write-Host " "
Write-host "Disabling Out of Office."
Set-MailboxAutoReplyConfiguration -Identity $DN -AutoReplyState Disabled -InternalMessage $null -ExternalMessage $null

# Disabling Email Address Policy
Write-Host " "
Write-host "Disabling Email Address Policy"
Set-Mailbox $dn -EmailAddressPolicyEnabled $false

#Hiding from Exchange Address Lists
Write-Host " "
Write-Host "Hiding from Exchange Address Lists"
Set-Mailbox $dn -HiddenFromAddressListsEnabled $true

# Setting mail forwarding
if ($Null -ne $ForwardToDN) {Write-Host " "}
if ($Null -ne $ForwardToDN) {Write-Host "Setting mail forwarding to $ForwardTo"}
if ($Null -ne $ForwardToDN) {Set-Mailbox -Identity $DN -ForwardingAddress $ForwardToDN -DeliverToMailboxAndForward:$false}

# Grant Full Access Permissions to a user
if ($Null -ne $FullAccessToDN) {Write-Host " "}
if ($Null -ne $FullAccessToDN) {Write-Host "Granting Full Mailbox Access to $FullAccessTo"} 
if ($Null -ne $FullAccessToDN) {Add-MailboxPermission -Identity $DN -user $FullAccessTo -AccessRights FullAccess -Confirm:$False | Out-Null} 

# Move AD account to Inactive Users OU
Write-Host " "
Write-Host "Moving AD Account to $TerminatedUsersOU"
Move-ADObject -Identity $dn -TargetPath $TerminatedUsersOU -Confirm:$false

# Force AD replication
Write-Host " "
Write-Host "Forcing Active Directory replication"
repadmin /syncall /e | Out-Null

Write-Host "Sleeping for 30 seconds."
Start-Sleep 30

$ADUser = Get-ADUser $SAMAccountName -Properties * # Gathers ALL AD account info for the user and stores it in a variable
$DN = $ADUser.DistinguishedName # Sets variable for DistinguishedName of user
$CN = $ADUser.CanonicalName # Sets variable for CanonicalName of the user
$SAMAccountName = $ADuser.SAMAccountName

# Move User Mailbox to Terminated Users Mailbox Database
Write-Host " "
Write-Host "Moving Mailbox to $TermMDB"
New-MoveRequest -Identity $dn -TargetDatabase $TermMDB | Out-Null

#
#Gather user information post modifications
Write-Host " "
Write-Host "Now gathering post-modification information"
$TermOutputFile = $OutputFolder2+$SAMAccountName+"-TerminationReport.txt"
$TermUser = Get-ADUser $SAMAccountName -properties *
$TermDN = ($TermUser).DistinguishedName
$TermCN = ($TermUser).CanonicalName
"Termination run by $RanAs at $Date-$Time" | Out-File $TermOutputFile -Append
"AD Info:" | Out-File $TermOutputFile -Append
$TermUser | Select CanonicalName, Enabled, Description | fl | Out-File $TermOutputFile -Append

# Build a list of all group that this user belongs to post modifications
$TermSecGroups = Get-ADGroup -Filter * -Properties * | Where {$_.GroupCategory -eq "Security"} | Where {$_.Members -like $TermDN} # Sets variable containing all security groups that the user is in
"Security Groups:" | Out-File $TermOutputFile -Append
" " | Out-File $TermOutputFile -Append
$TermSecGroups.name | Sort | fl| Out-File $TermOutputFile -Append
" " | Out-File $TermOutputFile -Append
$TermDistGroups = Get-ADGroup -Filter * -Properties * | Where {$_.GroupCategory -eq "Distribution"} | Where {$_.Members -like $TermDN} # Sets variable containing all distribution groups that the user is in
"Distribution Groups:" | Out-File $TermOutputFile -Append
" " | Out-File $TermOutputFile -Append
$TermDistGroups.name | Sort | fl | Out-File $TermOutputFile -Append
" " | Out-File $TermOutputFile -Append
" " | Out-File $TermOutputFile -Append

#Gather Mailbox Info post modifications
$TermMailBox = Get-Mailbox $TermDN
"Mailbox Info:" | Out-File $TermOutputFile -Append
$TermMailbox | Select Name, ForwardingAddress, HiddenFromAddressListsEnabled |fl| Out-File $TermOutputFile -Append

#Gather Full Mailbox Permissions post modifications
"Full Mailbox Permissions:" | Out-File $TermOutputFile -Append
$TermMBPermissions = Get-MailboxPermission -Identity $TermDN | Where {($_.AccessRights -like "*FullAccess*") -and ($_.IsInherited -eq $False)}
$TermMBPermissions | Select User, AccessRights, IsInherited | fl | Out-File $TermOutputFile -Append

# Getting ActiveSync Device Information post mofications
$TermActiveSyncDevices = Get-ActiveSyncDevice -ResultSize unlimited | Where {$_.Identity -like "*$TermCN*"}
"ActiveSync Devices:" | Out-File $TermOutputFile -Append
" " | Out-File $TermOutputFile -Append
if ($Null -ne $TermActiveSyncDevices) {$TermActiveSyncDevices | fl | Out-File $TermOutputFile -Append}
" " | Out-File $TermOutputFile -Append

# Getting Out of Office Settings post modifications
$TermOutOfOffice = Get-MailboxAutoReplyConfiguration -Identity $TermDN
"Out of Office settings:" | Out-File $TermOutputFile -Append
$TermOutOfOffice | Select AutoReplyState, ExternalMessage, InternalMessage | fl |Out-File $TermOutputFile -Append

$Attachments = gci $OutputFolder2 *.txt
Send-MailMessage -SmtpServer $SMTPServer -From $EmailFrom -To $EmailTo -Subject "$CN has been terminated in AD" -Body "Terminated by $RanAs" -Attachments $Attachments.fullname

Write-Host " "
Read-Host "Complete.  Press enter key to exit"