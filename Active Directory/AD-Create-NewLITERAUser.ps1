#  Set AD Path to OU for new users
$path = "OU=New,OU=Current,OU=Users,OU=LiteraMS,DC=literams,DC=net"

$userGivenName = Read-Host "New User Given Name? "
$userSurname = Read-Host "New User Surname? "
$userName = Read-Host "New User Username (e.g. first.last)? "
$UserSAM = (($userName -replace '(?<=(.{20})).+'))
$userPassword = Read-Host "New User Password (min 14 characters)?"
$userDescription = Read-Host "New User Description? "
$name = $userGivenName + " " + $userSurname
$displayName = $userGivenName + " " + $userSurname 
$securePwd = ConvertTo-SecureString $userPassword -AsPlainText -Force
$UPN = $userName + "@litera.com"

$parms = @{
    'Name'              = $name;
    'AccountPassword'   = $securePwd;
    'DisplayName'       = $displayName; 
    'GivenName'         = $userGivenName; 
    'Description'       = $userDescription; 
    'Path'              = $path; 
    'SamAccountName'    = $userSAM; 
    'Surname'           = $userSurname; 
    'UserPrincipalName' = $UPN; 
    'Enabled'           = $true;
}

New-ADUser @parms
