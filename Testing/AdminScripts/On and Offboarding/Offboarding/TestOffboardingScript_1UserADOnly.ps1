# Import the Active Directory module
Import-Module ActiveDirectory

# Set the variables, and perform offboarding steps 
    $Username = Read-Host "Enter the username of the employee to be offboarded"
    $UserSAM = ($Username -replace '(?<=(.{20})).+')
    $Password = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 20 | % {[char]$_})

# Disable, change the password, and remove user from groups for the user's account in Active Directory
    # Check if the account is already disabled
    if ((Get-ADUser -Identity $UserSAM).Enabled -eq $false) {
        # Account is already disabled
        Write-Output "$Username is already disabled. Skipping disable account step."
    }
    else {
        # Disable the user's account in Active Directory
        Disable-ADAccount -Identity $UserSAM
    }
Set-ADAccountPassword -Identity $UserSAM -NewPassword (ConvertTo-SecureString -AsPlainText $Password -Force)
Get-ADPrincipalGroupMembership $UserSAM | ForEach-Object {if(($_.name -ne "Domain Users") -and ($_.name -notlike "group_*")) {Remove-ADGroupMember -Identity $_ -Members $UserSAM -Confirm:$false}}