<#
.SYNOPSIS
    Mail-Enable multiple users in local Exchange from a CSV file.
.DESCRIPTION
    This script reads user details from a CSV file and enables each user for mail in an on-premises Exchange environment.
    It constructs the User Principal Name (UPN) and Remote Routing Address (RRA) based on the username provided in the CSV.
    The script requires appropriate permissions to enable remote mailboxes in Exchange.
.NOTES
    Version: 1.0
    Updated: June 16, 2025
    Author: Josh Conway
    Previous: N/A
    Changelog:
        1.0 - Initial version
#>

#Store the data from ADUsers.csv in the $ADUsers variable
$ADUsers = Import-csv PATH\TO\CSV\bulk_users1.csv

#Loop through each row containing user details in the CSV file 
foreach ($User in $ADUsers) {
    #Read user data from each field in each row and assign the data to a variable as below
		
    $Username = $User.username
    $upn      = $Username + "@DOMAIN.com"
    $RRA      = $Username + "@DOMAIN.mail.onmicrosoft.com"
   
    #Begin mail enabling users
    Enable-RemoteMailbox $upn -RemoteRoutingAddress $RRA
}