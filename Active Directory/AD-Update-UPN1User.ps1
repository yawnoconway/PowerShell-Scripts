Write-Host "This script will update UPN for a single, specific user.  This will usually be for a specific user that you have just created."  
Write-Host "  "
Write-Host "When prompted, simply provide the SamAccountName for the specific user." 

$sam = Read-Host "Enter SamAccountName for User: "

$User = Get-ADUser -Identity $sam

$newUPN = $user.SamAccountName+"@litera.com"

Set-ADUser -Identity $sam -UserPrincipalName $newUPN

Get-ADuser $sam