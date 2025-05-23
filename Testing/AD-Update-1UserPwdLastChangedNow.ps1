Write-Host "This script will update Pwd Last set for a single, specific user."  
Write-Host "  "
Write-Host "When prompted, simply provide the SamAccountName for the specific user." 

$sam = Read-Host "Enter SamAccountName for User: "

$ADUser = Get-ADUser $sam


        # Set the password to expired, must be done first.
        $ADUser.pwdLastSet = 0
        # Set the account so that the password expires.
        $ADUser.PasswordNeverExpires = $False
        # Save the changes
        Set-ADUser -Instance $ADUser 
 
        # Reset the date of the last password change to today.
        $ADUser.pwdLastSet = -1
        # Save the changes
        Set-ADUser -Instance $ADUser
 
        # Inform the user of the script that the account was changed.
        Write-Host    $ADUser.Name+"  Account Changed."
 