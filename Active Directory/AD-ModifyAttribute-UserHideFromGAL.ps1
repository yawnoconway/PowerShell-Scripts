$BaseOU = Read-Host -Prompt "Enter the OU of users to modify. (e.g. 'OU=Current,OU=Users,OU=Business,DC=Example,DC=net')"

$users = get-adobject -filter {objectclass -eq "user"} -searchbase $BaseOU
foreach ($User in $users)
{
    Set-ADObject $user -replace @{msExchHideFromAddressLists=$true}
    Set-ADObject $user -clear ShowinAddressBook
}