#Sleep Warning
Write-Host "There is a 60 second sleep command in the middle of hte script, please be patient and don't panic."

#Get on premise AD Admin Credentials
$Credential = $host.ui.PromptForCredential("Need on premise AD credentials", "Please enter your CAMP Domain Admin Credentials", "", "NetBiosUserName")

#Get Employee samaccountname to terminate
$samaccountname = Read-Host -Prompt 'Employee To Terminate'

#Description Input
$Description = Read-Host -Prompt "Please enter termination information that will be set as the Description"

#Form UPN of terminated user
$Terminate = $samaccountname+"@contoso.com"

#AD and AD Sync Server
$server = "<domain controller>"

#Gather DN
$UserDN = (Get-ADUser -Identity $samaccountname).distinguishedName

#Terminated Employees OU
$TargetOU = "OU=Terminated Employees,DC=contoso,DC=com"

#Password Randomizer
function Get-RandomCharacters($length, $characters) {
$random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
$private:ofs = ""
return [String]$characters[$random]
}

function Scramble-String([string]$inputString) {
$characterArray = $inputString.ToCharArray()
$scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length
$outputString = -join $scrambledStringArray
return $outputString
}
#Password Parameters
$password = Get-RandomCharacters -length 5 -characters 'abcdefghiklmnoprstuvwxyz'
$password += Get-RandomCharacters -length 1 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
$password += Get-RandomCharacters -length 1 -characters '1234567890'
$password += Get-RandomCharacters -length 1 -characters '!"§$%&/()=?}][{@#*+'

$password = Scramble-String $password

#Change Password and set description
set-adaccountpassword -Identity $samaccountname -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $Password -Force) -Server $server -Credential $credential

#Set Description
Set-AdUser -identity $samaccountname -description $Description -Server $server -Credential $credential

#Disable Account
Disable-ADAccount -Identity $samaccountname -Server $server -Credential $credential

#Move to terminated accounts OU
Move-ADObject -Identity $UserDN -TargetPath $TargetOU -Server $server -Credential $credential

#Remove Groups except domain users
Get-ADPrincipalGroupMembership $samaccountname -server $server -credential $credential | Where{$_.Name -ne "Domain Users"} | foreach {Remove-ADPrincipalGroupMembership -Identity $samaccountname -MemberOf $_ -Confirm:$false -server $server -credential $credential}

#Start AD Sync Cycle
invoke-command -ComputerName $server -Credential $credential -ScriptBlock {Start-ADSyncSyncCycle -PolicyType Delta}

#Wait 1 Minute
Start-Sleep -s 60

#O365 Tenant Info
$orgName = "contoso"

#Get O365 Admin Credentials
$O365Admin = $host.ui.PromptForCredential("Need O365 Admin Credentials", "Please enter your O365 Admin Credentials.", "", "NetBiosUserName")

#Connect to Azure AD and Sharepoint
Connect-AzureAD -Credential $O365Admin

#Connect to Sharepoint Online
Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking
Connect-SPOService -Url https://$orgName-admin.sharepoint.com -credential $O365Admin

#Connect to Exchange Online
$exchangeSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://outlook.office365.com/powershell-liveid/" -Credential $O365Admin -Authentication "Basic" -AllowRedirection
Import-PSSession $exchangeSession -DisableNameChecking

#Convert to shared mailbox
Set-mailbox -identity $Terminate -type Shared

#Revoke Azure AD Token
Get-AzureADUser -ObjectId $Terminate | Revoke-AzureADUserAllRefreshToken

#Revoke Sharepoint Online Session
Revoke-SPOUserSession -User $Terminate -confirm:$false

#Remove Licenses
$a = get-azureaduser -ObjectId $terminate
$skuids = $a.AssignedLicenses.skuid
$License = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
$LicensesToAssign = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
$LicensesToAssign.AddLicenses = @()
foreach($skuid in $skuids){$License.SkuId = $skuid; $LicensesToAssign.RemoveLicenses = $License.SkuId; Set-AzureADUserLicense -ObjectId $terminate -AssignedLicenses $LicensesToAssign}

#Print Password
Write-Host "New Password for $samaccountname =" $Password