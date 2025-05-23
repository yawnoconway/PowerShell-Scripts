## Example PowerShell script to export learner data from Windows AD to a CSV file

# Function to remove BOM from csv files exported by Windows Powershell ( script will run unaffected in PS 6 and above )
Function Remove-UTF8BOM
    {
    [CmdletBinding()]
    Param([parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$Path)
    Process {[System.IO.File]::WriteAllLines($Path, (Get-Content $Path -Raw), (New-Object System.Text.UTF8Encoding $False))}
    }

# Make sure Powershell 5.1 is using TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12



#Get users from Windows AD

# Set the Active Directory OU as required below ( if the below left commented all users from AD will be returned )
$BaseOU = "OU=Current,OU=Users,OU=LiteraMS,DC=literams,DC=net"

$users = Get-ADUser -Filter * -Properties * -SearchBase $BaseOU
$List = New-Object -TypeName System.Collections.ArrayList 

#verify that there are users
if ($users.Length -gt 0) { 
    foreach ($user in $users) {
        #Set Status: Active or inactive ( should avoid inactive AD users being uploaded to the LMS ) 
        $Status = "I"
        if ($user.Enabled -eq $true) {
            $Status = "A"
        }
        $startDate = $user.WhenCreated.ToString("yyyy-MM-dd")
        
        #Get manager's email address
        $manager = Get-ADUser -Identity $user.Manager -Properties employeeID
        $managerID = $manager.employeeID

        #create LMS user structure
        $userObj = [PSCustomObject]@{
            ################################################################################################################
            #
            # Items not required have been commented out however check your requirements if you already have data in the LMS
            #
            # Details can be found here https://protect-us.mimecast.com/s/gzbkC2kEEDuRmmGrs2hk7s?domain=intellekhelp.com
            # and https://protect-us.mimecast.com/s/D0_WC31GGVfG44M3fQYrXj?domain=intellekhelp.com
            #
            ################################################################################################################

            # NOTE "Client_User_Identifier" IS A UNIQUE KEY IN THE SYSTEM SO ONCE SET IT MUST REMAIN UNCHANGED - Existing users will already have this set
            #The unique identifier Maximum length 104 - Not Required unless users are already created in the system although setting the value at creation can be helpful 
            Client_User_Identifier = $user.employeeID

            #The identifier that the user will use when logging into the LMS, for Azure AD SSO this is the UPN ( generally users email address) . Maximum length 104            
            User_Identifier = $user.EmailAddress
            
            #Password - Not Required except if not using SSO
            #Password = ''

            #The user’s first name. Maximum length 100
            First_Name = $user.GivenName
            
            #The user’s last name. Maximum length 100
            Last_Name = $user.SurName
            
            #The code for the job title. Maximum length 256 - Not Required
            # Title_Code = ''
            
            #The name for the job title. Maximum length 256 - Not Required
            Title_Description = $user.title
            
            #The code for the profile. Maximum length 256 - Not Required
            # profile_code = ''
            
            #The name for the profile. Maximum length 256 - Not Required
            Profile_Description = $user.jobclass
            
            #The code for the department. Maximum length 256 - Not Required
            # Department_Code = '' 
            
            #The name for the department. Maximum length 256 - Not Required
            Department_Description = $user.Department
            
            #The code for the practice area. Maximum length 256 - Not Required
            # Practice_Area_Code = ''

            #The name for the practice area. Maximum length 256 - Not Required
            Practice_Area_Description = ''
            
            #See Location code for the full definition. - Not Required
            # Location_Code = ''
            
            # If you do not have / do not want to use the $user.Office as the Location_Description uncomment the line below and set a default one also replace $user.Office with $location in the line below that
            # $location = 'Some location description'
            #See Location name for the full definition.
            Location_Description = $user.Office 
            
            #The record status. The possible values are A or I ( set in this script based on if user is enabled in AD, see script lines 12 to 14)
            Status = $Status
            
            # Users phone number - Not Required
            Telephone_Number = $user.employeeType 
            
            #The user’s unique email address. Maximum length 359
            Email_Address = $user.EmailAddress
            
            #The date the user started / will start with the company. The format is ‘yyyy-MM-dd’ - Not Required
            # In this script calculated based on user creation time ( see line 16 )
            Start_Date = $user.extensionAttribute11
    
            #The date the user left / will leave the company. The format is ‘yyyy-MM-dd’ - Not Required
            # End_Date = $user.accountExpires
    
            #The client_user_identifier of the person who supervises this user. Maximum length 104. The default value is system. - Not Required
            Client_Manager_Identifier = $managerID
            
            #Security Profiles control the various “permissions” given to each user in the LMS, default value is Standard User - Not Required
            # SecurityProfileCode = '' 
    
            # Below address details not required
            # Street1 = ''
            # Street2 = ''
            # City = ''
            # State = ''
            # Zip = ''
            # Country = ''

            # Users birth date - - Not Required
            # Birth_Date = ''
    
    }
        $userObj.PSobject.Properties | ForEach-Object{if( $userObj."$($_.Name)" -eq $null){$userObj."$($_.Name)"}}
        $list.Add($userObj)
    }
    
    #Export CSV file - Update output location as required
    $path = 'C:\Users\jmconway\Documents\Import_Learners.csv'
    $List | Export-CSV $path -NoTypeInformation -Encoding UTF8
    Remove-UTF8BOM $path

}