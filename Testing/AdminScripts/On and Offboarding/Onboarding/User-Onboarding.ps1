# Import active directory module for running AD cmdlets
Import-Module activedirectory

$DAcred = Read-Host -Prompt "Please enter the name of your DA credential "
$DApass = Read-Host -Prompt "Please enter your DA Password" -AsSecureString
  
#Store the data from ADUsers.csv in the $ADUsers variable
$ADUsers = Import-csv C:\Users\sgdhaliwal\Downloads\bulk_users_ind.csv

#Loop through each row containing user details in the CSV file 
foreach ($User in $ADUsers)
{
	#Read user data from each field in each row and assign the data to a variable as below
		
	$Username 	= $User.username
	$Password 	= $User.password
	$Firstname 	= $User.firstname
	$Lastname 	= $User.lastname
	$employeetype = $User.emptype 
    $email      = $User.email
    $city       = $User.city
    $office     = $User.office
    $telephone  = $User.telephone
    $jobtitle   = $User.jobtitle
    $company    = $User.company
    $department = $User.department
    $manager    = $User.manager
    $Password = $User.Password

    if ($employeetype -eq "FTE") {
    $OU = "OU=India,OU=Staff,OU=Current,OU=Users,OU=LiteraMS,DC=literams,DC=net"
}
else {
    $OU = "OU=Arche Softronix,OU=Contractors,OU=Current,OU=Users,OU=LiteraMS,DC=literams,DC=net"
}


   
	#Check to see if the user already exists in AD
	if (Get-ADUser -F {SamAccountName -eq $Username})
	{
		 #If user does exist, give a warning
		 Write-Warning "A user account with username $Username already exist in Active Directory."
	}
	else
	{
		#User does not exist then proceed to create the new user account
		
        #Account will be created in the OU provided by the $OU variable read from the CSV file
		New-ADUser `
            -SamAccountName $Username `
            -UserPrincipalName "$Username@litera.com" `
            -Name "$Firstname $Lastname" `
            -GivenName $Firstname `
            -Surname $Lastname `
            -Enabled $True `
            -DisplayName "$Firstname $Lastname" `
            -Path $OU `
            -City $city `
            -Company $company `
            -State $state `
            -StreetAddress $streetaddress `
            -Office $office `
            -OfficePhone $telephone `
            -Manager $manager `
            -EmailAddress $email `
            -Title $jobtitle `
            -Department $department `
            -AccountPassword (convertto-securestring $Password -AsPlainText -Force) -ChangePasswordAtLogon $False
            
	}

if ($employeetype -eq "FTE") {

Add-ADGroupMember -Identity "Ahmedabad (ALL) Distribution List-1719598212" -Members $Username
Add-ADGroupMember -Identity "All-LMSEmployees" -Members $Username
Add-ADGroupMember -Identity "InTune-General" -Members $Username
Add-ADGroupMember -Identity "LP-AllUsers" -Members $Username
Add-ADGroupMember -Identity "SG-DruvaUsers-AP" -Members $Username
Add-ADGroupMember -Identity "SG-Intune-Autopilot-HardwareHash" -Members $Username
Add-ADGroupMember -Identity "SG-VPN-EMPLOYEES" -Members $Username
Add-ADGroupMember -Identity "SG-WVD-India" -Members $Username
#Add-ADGroupMember -Identity "Ahmedabad (All) Distribution List-1-1574610115" -Members $Username
Start-Sleep -Seconds 5

}
else {
Add-ADGroupMember -Identity "India-Remote Staff Distribution List-11433664547" -Members $Username
Add-ADGroupMember -Identity "InTune-General" -Members $Username
Add-ADGroupMember -Identity "LP-AllUsers" -Members $Username
Add-ADGroupMember -Identity "SG-DruvaUsers-AP" -Members $Username
Add-ADGroupMember -Identity "SG-Intune-Autopilot-HardwareHash" -Members $Username
Add-ADGroupMember -Identity "SG-WVD-India" -Members $Username
Add-ADGroupMember -Identity "SG-VPNAccess-ApprovedContractors" -Members $Username
Add-ADGroupMember -Identity "SG-ThirdPartyContractors" -Members $Username
Start-Sleep -Seconds 5
}


Enable-Mailbox -Identity "$Username" -Database "Mailbox Database 0686017263"
Start-Sleep -Seconds 5

}


$command = {
    Start-ADSyncSyncCycle -PolicyType Delta
} 
Invoke-Command -ComputerName srvr-egv1 -ScriptBlock $command

Start-Sleep -Seconds 20

$O365cred = New-Object System.Management.Automation.PSCredential -ArgumentList ($DAcred, $DApass)
Write-host "Please enter your DA credential with MFA authentication"
$acctName= $DAcred
$OrgName = "literams.mail.onmicrosoft.com"
Connect-MsolService
Import-Module ExchangeOnlineManagement        
Connect-ExchangeOnline -UserPrincipalName $acctName -ShowProgress $true
$Endpoint = "mail.literams.net"
$TargetDomain = "literams.mail.onmicrosoft.com"
Start-Sleep -Seconds 30

foreach ($User in $ADUsers)
{
	#Read user data from each field in each row and assign the data to a variable as below
		
	$Username 	= $User.username
    $Mailbox = "$Username@litera.com"
	
$j = $true
while ($j){

    if (Get-User -Identity $Mailbox| where {$_.RecipientType -eq "MailUser"}) {
                         
        Write-host " Migration of $Mailbox from local exchange to online exchange is in progress....."
        New-MoveRequest -Identity $Mailbox -Remote -RemoteHostName $Endpoint -TargetDeliveryDomain $TargetDomain -RemoteCredential $O365cred -Batchname "$Mailbox Move to O365"
        
        $j = $False
    } else {
            Start-Sleep -Seconds 30
           }

}
}

start-sleep -Seconds 180

foreach ($User in $ADUsers)
{
	#Read user data from each field in each row and assign the data to a variable as below
		
	$Username 	= $User.username
    $Mailbox = "$Username@litera.com"

    $i = $true
while ($i){

    if (Get-MoveRequest -Identity $Mailbox| where {$_.status -eq "Completed"}) {

        Write-host "$Mailbox is migrated from local exchange to online exchange successfully"
        Set-MsolUser -UserPrincipalName $Mailbox -UsageLocation US
        start-sleep -Seconds 30
        Set-MsolUserLicense -UserPrincipalName $Mailbox -AddLicenses "literams:SPE_E5"
        start-sleep -Seconds 30
        Set-CASMailbox -Identity "$Username@litera.com" -ImapEnabled $false
        Set-CASMailbox -Identity "$Username@litera.com" -PopEnabled $false
        Set-CASMailbox -Identity "$Username@litera.com" -ActiveSyncEnabled $false
        $i = $False
    } else {
            Start-Sleep -Seconds 10
           }

}
}


foreach ($User in $ADUsers)
{
	#Read user data from each field in each row and assign the data to a variable as below
		
	$Username 	= $User.username
    $employeetype = $User.emptype


if ($employeetype -eq "FTE") {

Add-UnifiedGroupLinks -Identity "AhmedabadOfficeTeams@literams.net" -LinkType "Members" -Links "$username@litera.com"
} else {
Write-host "$username is Contractor so not added in Ahmedabad Teams Channel"
}
} 