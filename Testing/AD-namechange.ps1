#Rename a User Account because of a Last Name Change or First Name Change, changes username in AD, Exchange Alias, and Azure AD UserPrincipalName
#This script is for an organization that synchronizes Active Directory with Office 365 and the user's first or last name and username needs to be changed
#This script must be run from the server with Azure AD Connect installed
Import-Module AzureAD
Import-Module ActiveDirectory;
Import-Module ADSync;
 
#Edit Variables Below
#Old Name
$oldfirstname='';
$oldlastname='';
$oldusername='';        
 
#New Name
$newfirstname='';
$newlastname='';
$newusername='';           
 
$logfile = 'c:\temp\UserAccountRename.txt';
 
 
#DisplayName and AD Object Name Format:
$newdisplayname = "$newfirstname $newlastname";
 
#UPN Format:
$oldupn="$oldusername@DOMAIN.com";
$newupn="$newusername@DOMAIN.com";
 
 
#Leave Variables alone below unless fixing a problem or if you have a different setup:
 
#Office 365 Credential Request
WRITE-HOST "Office 365 Credential Request";
$msolcred = get-credential;
 
#Local Exchange Admin Credential Request
WRITE-HOST  "Exchange Admin Credential Request";
$cred = get-credential;
 
 
WRITE-HOST "oldupn:$oldupn";
WRITE-HOST "newupn:$newupn";
 
$errormessage = "Start User Rename oldusername:$oldusername to newusername:$newusername";
Add-Content $logfile $errormessage;
 
#check if newusername already exists (could be a problem)
try 
{
    $user = Get-ADUser -Filter "sAMAccountName -eq '$newusername'" -SearchBase 'DC=DISTINGUISHED OU' -Properties cn,displayname,givenname,initials;
}
catch
{
    $errormessage ="";
}
 
#new username does not exit then we can move forward
if ($null -eq $user) 
{
 
    try 
    {
        $user = Get-ADUser -Filter "sAMAccountName -eq '$oldusername'" -SearchBase 'DC=DISTINGUISHED OU' -Properties cn,displayname,givenname,initials;
    }
    catch
    {
        $errormessage = "Error occurred looking up User with sAMAccountName '$oldusername' does not exist in the target OU.";
        Add-Content $logfile $errormessage;
    }
 
    if ($null -eq $user) 
    {
        $errormessage = "User with sAMAccountName '$oldusername' does not exist in the target OU.";
        Add-Content $logfile $errormessage;
    }
    else
    {
        # Try to modify the user account's username and upn, trapping errors if they occur
        try 
        { 
            $userDN=$($user.DistinguishedName);
            WRITE-HOST "Rename DN:$userDN";
            Set-ADUser -identity $userDN -sAMAccountName $newusername -UserPrincipalName $newupn -DisplayName $newdisplayname -SurName $newlastname -GivenName $newfirstname -ErrorVariable Err;
            Start-Sleep -Seconds 30;
            rename-adobject -identity $userDN  -newname $newdisplayname;
            Add-Content $logfile "User renamed in AD";
            WRITE-HOST "User Renamed Successfully";
        }     
        catch 
        {
            $errormessage = "Error renaming the user account $oldusername";
            Add-Content $logfile "$errormessage $_";
            WRITE-HOST "User Rename Failed!";
        }
 
        Start-Sleep -Seconds 60;
 
        #Exchange Connection/Session
        $sessionoption = New-PSSessionOption -SkipCNCheck;
         
        #Local Exchange Session
        $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://LocalExchangeServer/powershell/ -Credential $cred -AllowRedirection -SessionOption $sessionoption;
 
        Import-PSSession $Session;
 
        #Fix Alias with Exchange
        try 
        {
            #Fixes the Alias with Exchange to be the $newusername
            $exist = [bool](Get-Mailbox -identity $oldusername -ErrorAction SilentlyContinue);
            if ($exist)
            {
                #Mailbox is on local exchange server
                Get-Mailbox -Identity $oldusername | Set-Mailbox -Alias $newusername
            }
            else
            {
                #Mailbox possibly has been migrated to Office 365 Exchange Online
                Get-RemoteMailbox -identity $oldusername | Set-RemoteMailbox -Alias $newusername;
            }
             
             
            WRITE-HOST "Exchange Alias Changed Successfully newalias:$newusername";
        }
        catch
        {
            $errormessage = "Error changing the alias for $newusername";
            Add-Content $logfile "$errormessage $_";
            WRITE-HOST "Exchange Alias change failed!";
        }
        #Exit Session
        Remove-PSSession $Session;
 
        Start-Sleep -Seconds 120;
        #Synchronize local AD and Azure AD
        Start-ADSyncSyncCycle -PolicyType Delta;
        Start-Sleep -Seconds 180;
 
        #Connect to AD Online
        Connect-AzureAD -credential $msolcred;
 
         
        try 
        {
            #Fix UserPrincipalName with AD Online
            Set-AzureADUser -ObjectId $oldupn -UserPrincipalName $newupn;
            WRITE-HOST "Azure AD userprincipalname updated to $newupn"
        }
        catch
        {
            $errormessage = "Error renaming the upn with AD Online with the oldupn:$oldupn newupn:$newupn";
            Add-Content $logfile "$errormessage $_";
            WRITE-HOST "Azure AD userprincipalname change failed!";
        }
        Disconnect-AzureAD
         
    }
}
else
{
    $errormessage = "New Username with sAMAccountName '$newusername' already exists!";
    Write-Error $errormessage;
    Add-Content $logfile $errormessage;
     
}
$errormessage = "Finished User Rename oldusername:$oldusername to newusername:$newusername";
Add-Content $logfile $errormessage;
WRITE-HOST "Username Change Script Completed Running.";
WRITE-HOST "If OneDrive synchronization is used by the user then reimaging their computer might be necessary";
WRITE-HOST "Don't forget to change user's document share folder name to the new username as necessary and when not in use."
