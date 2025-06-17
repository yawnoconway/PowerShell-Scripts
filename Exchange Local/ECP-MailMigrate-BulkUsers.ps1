<#
.SYNOPSIS
    Add Synopsis Here
.DESCRIPTION
    Add Description Here
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