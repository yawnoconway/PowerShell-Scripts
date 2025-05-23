#Store the data from ADUsers.csv in the $ADUsers variable
$ADUsers = Import-csv C:\Users\Public\Documents\bulk_users1.csv

#Loop through each row containing user details in the CSV file 
foreach ($User in $ADUsers)
{
    #Read user data from each field in each row and assign the data to a variable as below
		
	$Username 	= $User.username
	$Password 	= $User.password
	$Firstname 	= $User.firstname
	$Lastname 	= $User.lastname
	$OU 		= $User.ou #This field refers to the OU the user account is to be created in
    $email      = $User.email
    $streetaddress = $User.streetaddress
    $city       = $User.city
    $zipcode    = $User.zipcode
    $state      = $User.state
    $country    = $User.country
    $telephone  = $User.telephone
    $jobtitle   = $User.jobtitle
    $company    = $User.company
    $department = $User.department
    $Password = $User.Password
    $upn        = "$Username@DOMAIN.com"
    $RRA        = "$Username@DOMAIN.mail.onmicrosoft.com"


    
    #Begin mail enabling users
    Enable-RemoteMailbox $upn -RemoteRoutingAddress $RRA
}