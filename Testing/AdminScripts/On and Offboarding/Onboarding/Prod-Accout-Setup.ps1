Import-Module ActiveDirectory
$firstname = Read-Host -Prompt "Please enter the first name with prod-"
$Originalfirstname = Read-Host -Prompt "Please enter the first name without prod-"
$lastname = Read-Host -Prompt "Please enter the last name"
$sam = Read-Host -Prompt "Please enter the SAM details which should not more than 20 characters"
$password = Read-Host -Prompt "Please enter the password (14 Characters)" -AsSecureString
$DAcred = Read-Host -Prompt "Please enter the name of your DA credential "
$DApass = Read-Host -Prompt "Please enter your DA Password" -AsSecureString
$OU = "OU=DevProdAccounts,OU=PeopleServiceAccts,OU=Users,OU=LiteraMS,DC=literams,DC=net"

#Create AD User
New-ADUser `
    -Name "$firstname $lastname" `
    -GivenName $firstname `
    -Surname $lastname `
    -UserPrincipalName "$sam@literams.net" `
    -SamAccountName $sam `
    -AccountPassword (ConvertTo-SecureString $password -AsPlainText -Force) `
    -Path $OU `
    -Enabled 1 

#Wait a specific interval
Start-Sleep -Seconds 10

Write-host "Creating the local exchange mailbox ......"

Enable-Mailbox -Identity "$sam" -Database "Mailbox Database 0686017263"

Start-Sleep -Seconds 10

Set-Mailbox "$sam" -PrimarySmtpAddress "$sam@literams.net" -EmailAddressPolicyEnabled $false

$command = {
    Start-ADSyncSyncCycle -PolicyType Delta
} 
Invoke-Command -ComputerName srvr-egv1 -ScriptBlock $command



$O365cred = New-Object System.Management.Automation.PSCredential -ArgumentList ($DAcred, $DApass)
Write-host "Please enter your DA credential with MFA authentication"
$acctName= $DAcred
$OrgName = "literams.mail.onmicrosoft.com"
Connect-MsolService
Import-Module ExchangeOnlineManagement        
Connect-ExchangeOnline -UserPrincipalName $acctName -ShowProgress $true

$Mailbox = "$sam@literams.net"
$Endpoint = "mail.literams.net"
$TargetDomain = "literams.mail.onmicrosoft.com"


Start-Sleep -Seconds 50

$j = $true
while ($j){

    if (Get-User -Identity $Mailbox| where {$_.RecipientType -eq "MailUser"}) {
                         
        Write-host " Migration from local exchange to online exchange is in progress....."
        Start-Sleep -Seconds 30
        New-MoveRequest -Identity $Mailbox -Remote -RemoteHostName $Endpoint -TargetDeliveryDomain $TargetDomain -RemoteCredential $O365cred -Batchname "$Mailbox Move to O365"
        
        $j = $False
    } else {
            Start-Sleep -Seconds 30
           }

}



#Add license to user mailbox

$i = $true
while ($i){

    if (Get-MoveRequest -Identity $Mailbox| where {$_.status -eq "Completed"}) {

        Write-host "Mailbox is migrated from local exchange to online exchange successfully"
        Set-MsolUser -UserPrincipalName $Mailbox -UsageLocation US
        Write-host "Assigning license temporary..."
        start-sleep -Seconds 30
        Set-MsolUserLicense -UserPrincipalName $Mailbox -AddLicenses "literams:EXCHANGESTANDARD"
        $i = $False
    } else {
            Start-Sleep -Seconds 100
           }

}


Invoke-Command -ComputerName srvr-egv1 -ScriptBlock $command


Write-host "Sending Test mail to prod account for the internal domain entry in mimecast....."

Start-Sleep -Seconds 180

$From = "test@literams.net"

$To = "$sam@literams.net"

$Subject = " test mail "

$Body = " test mail for the internal domain entry "

$SMTPServer = " 10.110.30.31 "

$SMTPPort = "25"

Send-MailMessage -From $From -to $To -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort

start-sleep -Seconds 15

Write-host "Converting mailbox from regular to shared mailbox..."

#Convert to shared mailbox
Set-Mailbox $Mailbox -Type Shared

Write-host "Removing assigned license..."

start-sleep -Seconds 60

#Remove the Licesnse
Set-MsolUserLicense -UserPrincipalName $Mailbox -RemoveLicenses "literams:EXCHANGESTANDARD"

#email forwarding to litera email address
Set-Mailbox -Identity "$sam" -ForwardingAddress "$Originalfirstname.$lastname@litera.com"

Send-MailMessage -From $From -to "surinder.dhaliwal@litera.com" -Subject "prod account $To created successfully" -Body "prod account $To created successfully"  -SmtpServer $SMTPServer -port $SMTPPort

Write-host "Account is created successfully"