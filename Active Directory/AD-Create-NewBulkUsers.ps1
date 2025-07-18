<#
.SYNOPSIS
    Bulk create new Active Directory users from a CSV file.
.DESCRIPTION
    This script allows you to bulk create new Active Directory user accounts using a CSV file.
    The CSV file should contain columns for username, password, first name, last name, OU, email, country, job title, company, department, and description.
    The script will read the data from the CSV file and create user accounts in the specified OU.
.NOTES
    Version: 1.0
    Updated: June 16, 2025
    Author: Josh Conway
    Previous: N/A
    Changelog:
        1.0 - Initial version
#>

# Import active directory module for running AD cmdlets
Import-Module activedirectory
  
#Store the data from ADUsers.csv in the $ADUsers variable
$ADUsers = Import-csv "PATH\TO\CSV\bulk_users1.csv"

#Loop through each row containing user details in the CSV file 
foreach ($User in $ADUsers) {
    #Read user data from each field in each row and assign the data to a variable as below
		
    $userName = $User.username
    $Password = $User.password
    $userGivenName = $User.firstname
    $userSurname = $User.lastname
    $OU = $User.ou #This field refers to the OU the user account is to be created in
    $email = $User.email
    $samAccountName = (($userName -replace '(?<=(.{20})).+'))
    $UPN = $userName + "@DOMAIN.com"
    $country = $User.country
    $jobtitle = $User.jobtitle
    $company = $User.company
    $department = $User.department
    $description = $User.description
    $Password = ConvertTo-SecureString $User.Password -AsPlainText -Force


    #Check to see if the user already exists in AD
    if (Get-ADUser -F { samAccountName -eq $samAccountName }) {
        #If user does exist, give a warning
        Write-Warning "A user account with username $userName already exist in Active Directory."
    }
    else {
        #User does not exist then proceed to create the new user account
		
        $parms = @{
            'Name'              = $userGivenName + " " + $userSurname;
            'AccountPassword'   = $Password;
            'DisplayName'       = $userGivenName + " " + $userSurname;
            'GivenName'         = $userGivenName;
            'Description'       = $description;
            'Department'        = $department;
            'Company'           = $company;
            'Country'           = $country;
            'Title'             = $jobtitle;
            'Path'              = $OU;
            'samAccountName'    = $samAccountName;
            'Surname'           = $userSurname;
            'UserPrincipalName' = $UPN;
            'EmailAddress'      = $email;
            'Enabled'           = $true;
        }

        #Account will be created in the OU provided by the $OU variable read from the CSV file
        New-ADUser @parms
    }
}
