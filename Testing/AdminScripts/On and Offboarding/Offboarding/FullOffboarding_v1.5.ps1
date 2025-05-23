# Changelog
# 1.5 - Now clears manager field, grabs group memberships, wipes mobile outlook containers, removed mailbox foward,
#       added mailbox full access, and connects to Graph to removes 365 groups and licenses
# 1.2 - Will now modify Emp Status and Ext Attr 14 to "Inactive"
# 1.1 - Added moving to disabled OU, and a list of script functions
# 1.0 - Initial version

# Import the Active Directory Module
if (!(Get-Module ActiveDirectory -ListAvailable -ErrorAction SilentlyContinue)) {
    Import-Module ActiveDirectory
}
# Import the Exchange Online Module
if (!(Get-Module ExchangeOnlineManagement -ListAvailable -ErrorAction SilentlyContinue)) {
    Import-Module ExchangeOnlineManagement
}
# Connect & Login to ExchangeOnline (MFA)
if ((Get-PSSession -Name 'ExchangeOnlineInternalSession*' -ErrorAction SilentlyContinue).Count -eq 0) {
    Connect-ExchangeOnline -ErrorAction SilentlyContinue
}
# Import the Graph Module
if (!(Get-Module Microsoft.Graph -ListAvailable -ErrorAction SilentlyContinue)) {
    Import-Module Microsoft.Graph
}
# Connect & Login to MS Graph
Connect-Graph -Scopes User.ReadWrite.All, Organization.Read.All, Group.ReadWrite.All

function ShowNedry {
    Write-Host "*Insert Nedry wagging his finger*"
    # Repeat the quote every 2 seconds infinitely
    while ($true) {
        Write-Host "Ah Ah Ah, you didn't say the magic word!"
        Start-Sleep -Seconds 2
    }
}

$banner = @'
    __    _ __                                                             
   / /   (_) /____  _________ _                                            
  / /   / / __/ _ \/ ___/ __ `/                                            
 / /___/ / /_/  __/ /  / /_/ /                                             
/_____/_/\__/\___/_/   \__,_/               ___                     ___
  / __ \/ __/ __/ /_  ____  ____ __________/ (_)___  ____ _        <  /   ____
 / / / / /_/ /_/ __ \/ __ \/ __ `/ ___/ __  / / __ \/ __ `/   _  __/ /   / __/
/ /_/ / __/ __/ /_/ / /_/ / /_/ / /  / /_/ / / / / / /_/ /   | |/ / /   /__ \
\____/_/ /_/ /_.___/\____/\__,_/_/   \__,_/_/_/ /_/\__, /    |___/_/(_)/____/ 
                                                  /____/

'@
Write-Host $banner -ForegroundColor Yellow
Write-Host "This script will do the following in this order:

           1. Disable AD account
           2. Change password
           3. Modify Emp Status and Ext Attr 14 to 'Inactive'
           4. Clear manager field
           5. Capture group memberships and export as csv
           6. Remove user from AD groups
           7. Move them to the Disabled Users OU
           8. Hide from GAL
           9. **Wipe and/or block mobile device outlook containers** Removed for testing
          10. Convert to shared mailbox
          11. Set mailbox 'Full Access' permission if specified
          12. Remove 365 Licenses from User
          13. Removes User from 365 groups
           " -ForegroundColor Cyan

$OffboardingComplete = $False
while ($OffboardingComplete -eq $False) {
    try {
        $answer = Read-Host "Are you offboarding a single user, or in bulk? (Single/Bulk)"

        switch ($answer) {
            "Single" {
                # Commands to Run for Single User

                # Set the Variables 
                $Username = Read-Host "Enter the username of the employee to be offboarded"
                $FullAccessUser = Read-Host "Enter the username for who will gain full access to mailbox. Leave blank for no one"
                $UserSAM = ($Username -replace '(?<=(.{20})).+')
                $UserMail = ($Username + "@litera.com")
                $Password = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 20 | ForEach-Object { [char]$_ })
                $FullAccessAddress = ($FullAccessUser + "@litera.com")

                # Disable and Change the Password
                if ((Get-ADUser -Identity $UserSAM).Enabled -eq $false) {
                    Write-Output "$Username is already disabled. Skipping disable account step."
                }
                else {
                    Disable-ADAccount -Identity $UserSAM
                }
                Set-ADAccountPassword -Identity $UserSAM -NewPassword (ConvertTo-SecureString -AsPlainText $Password -Force)
                
                # Modify Attributes in AD
                Set-ADUser -Identity $UserSAM -Replace @{empstatus = 'Inactive' }
                Set-ADUser -Identity $UserSAM -Replace @{extensionAttribute14 = 'Inactive' }
                Set-ADUser -Identity $UserSAM -Manager $null
                
                # Export Group Membership and Remove 
                Get-MgUserMemberOf -UserId $UserMail | ForEach-Object { Get-MgGroup -GroupId $_.Id } | Select-Object DisplayName | Export-Csv -Path "C:\AdminScripts\On and Offboarding\Offboarding\Group Memberships\$username.csv" -NoTypeInformation
                Get-ADPrincipalGroupMembership $UserSAM | ForEach-Object { if (($_.name -ne "Domain Users") -and ($_.name -notlike "group_*")) { Remove-ADGroupMember -Identity $_ -Members $UserSAM -Confirm:$false } }

                # Hide User from the GAL in Local Exchange via AD
                Get-ADuser -Identity $UserSAM -property msExchHideFromAddressLists |  
                Set-ADObject -Replace @{msExchHideFromAddressLists = $true } 
                
                # Move User to 'Disabled' OU
                Move-ADObject -Identity (Get-ADUser -Filter { sAMAccountName -eq $UserSAM }).DistinguishedName -TargetPath "OU=Disabled,OU=Users,OU=LiteraMS,DC=literams,DC=net"

                # Mobile Device Outlook Account Wipe/Block

                # iOS/Android/ActiveSync Devices
                #                $MobileDevices = Get-MobileDevice -Identity $UserMail -ResultSize unlimited | Where-Object { ($_.ClientType -eq "EAS") -or ($_.DeviceModel -eq "Outlook for iOS and Android") }

                #                ForEach ($MobileDevice in $MobileDevices) {
                #                    Clear-MobileDevice $MobileDevice.Identity -AccountOnly -Confirm:$false
                #                }

                # Mac/Windows etc.
                #                $OtherDevices = Get-MobileDevice -Mailbox $UserMail -ResultSize unlimited | Where-Object { ($_.ClientType -ne "EAS") -and ($_.DeviceModel -ne "Outlook for iOS and Android") }
                    
                #                ForEach ($OtherDevice in $OtherDevices) {
                #                    Try {
                #                        Clear-MobileDevice $OtherDevice.Identity -AccountOnly -Confirm:$false -ErrorAction Stop
                #                    }
                #                    Catch {
                #                        Write-Host "Account-only wipe failed for device $($OtherDevice.DeviceModel) with identity $($OtherDevice.Identity). Blocking device instead." -ForegroundColor Yellow
                #                        $BlockedDeviceIDs = @($OtherDevice.DeviceID)
                #                        Set-CASMailbox $UserMail -ActiveSyncBlockedDeviceIDs $BlockedDeviceIDs
                #                    }
                #                }
                
                # Convert User's Mailbox to Shared and Set Full Access Delegation
                if ($null -eq $FullAccessUser -or $FullAccessUser.Length -eq 0) {
                    Set-Mailbox -Identity $UserMail -Type Shared
                }
                else {
                    Set-Mailbox -Identity $UserMail -Type Shared
                    Add-MailboxPermission -Identity $UserMail -User $FullAccessAddress -AccessRights FullAccess -InheritanceType All
                }

                # Remove Microsoft Licensing
                $mguser = Get-MgUser -UserId $UserMail -ErrorAction SilentlyContinue
                if (($mguser)) {
                    try {
                        $SKUs = @(Get-MgUserLicenseDetail -UserId $mguser.id)
                        if (!$SKUs) {
                            Write-Host "No Licenses found for user $UserMail, skipping..."
                        }
                        foreach ($SKU in $SKUs) {
                            Write-Host "Removing license $($SKU.SkuPartNumber) from user $UserMail"
                            try {
                                Set-MgUserLicense -UserId $mguser.id -AddLicenses @() -RemoveLicenses $Sku.SkuId -ErrorAction Stop #-WhatIf
                            }
                            catch {
                                if ($_.Exception.Message -eq "User license is inherited from a group membership and it cannot be removed directly from the user.") {
                                    Write-Host "License $($SKU.SkuPartNumber) is assigned via the group-based licensing feature, either remove the user from the group or unassign the group license, as needed."
                                }
                                else { $_ | Format-List * -Force } #catch-all for any unhandled errors
                            }
                        }
                    }
                    catch {
                        Write-Host "An error occurred: $($_.Exception.Message)"
                    }
                }
                else {
                    Write-Host "User $UserMail not found in 365 Admin. Please verify license removal in portal."
                }

                # Remove User from 365 Groups
                $mguser = Get-MgUser -UserId $UserMail -ErrorAction SilentlyContinue
                if (($mguser)) {
                    try {
                        $msgroupMemberships = @(Get-MgUserMemberof -UserId $mguser.id)
                        if (!$msgroupMemberships) {
                            Write-Host "No groups found for user $UserMail, skipping..."
                        }
                        foreach ($group in $msgroupMemberships) {
                            try {
                                Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $mguser.id -Confirm:$false
                                Write-Host "User removed from group: $($group.DisplayName)"
                            }
                            catch {
                                $_ | Format-List * -Force #catch-all for any unhandled errors
                            }
                        }
                    }
                    catch {
                        Write-Host "An error occurred: $($_.Exception.Message)"
                    }
                }
                else {
                    Write-Host "User $UserMail not found in 365 Admin.  Please verify group removal in portal."
                }
                $OffboardingComplete = $True
            }
            "Bulk" {
                $confirmation = Read-Host "Are you sure you want to proceed with Bulk User offboarding? (Y/N)"
                if ($confirmation -eq "Y") {
                    # Commands to Run for Bulk Users

                    # Import the CSV and Set the Variables 
                    Import-Csv -Path C:\Users\Public\Documents\BulkOffboarding.csv | ForEach-Object {
                        $Username = ($_.username)
                        $UserSAM = ($Username -replace '(?<=(.{20})).+')
                        $UserMail = ($Username + "@litera.com")
                        $Password = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 20 | ForEach-Object { [char]$_ })
                        $ForwardingAddress = $($_.ForwardingAddress)

                        # Disable and Change the Password
                        if ((Get-ADUser -Identity $UserSAM).Enabled -eq $false) {
                            Write-Output "$Username is already disabled. Skipping disable account step."
                        }
                        else {
                            Disable-ADAccount -Identity $UserSAM
                        }
                        Set-ADAccountPassword -Identity $UserSAM -NewPassword (ConvertTo-SecureString -AsPlainText $Password -Force)

                        # Modify Attributes in AD
                        Set-ADUser -Identity $UserSAM -Replace @{empstatus = 'Inactive' }
                        Set-ADUser -Identity $UserSAM -Replace @{extensionAttribute14 = 'Inactive' }
                        Set-ADUser -Identity $UserSAM -Manager $null

                        # Export Group Membership and Remove
                        Get-MgUserMemberOf -UserId $UserMail | ForEach-Object { Get-MgGroup -GroupId $_.Id } | Select-Object DisplayName | Export-Csv -Path "C:\AdminScripts\On and Offboarding\Offboarding\Group Memberships\$username.csv" -NoTypeInformation
                        Get-ADPrincipalGroupMembership $UserSAM | ForEach-Object { if (($_.name -ne "Domain Users") -and ($_.name -notlike "group_*")) { Remove-ADGroupMember -Identity $_ -Members $UserSAM -Confirm:$false } }
        
                        # Hide User from the GAL in Local Exchange via AD
                        Get-ADuser -Identity $UserSAM -property msExchHideFromAddressLists |  
                        Set-ADObject -Replace @{msExchHideFromAddressLists = $true }

                        # Move User to 'Disabled' OU
                        Move-ADObject -Identity (Get-ADUser -Filter { sAMAccountName -eq $UserSAM }).DistinguishedName -TargetPath "OU=Disabled,OU=Users,OU=LiteraMS,DC=literams,DC=net"

                        # Mobile Device Outlook Account Wipe/Block

                        # iOS/Android/ActiveSync Devices
                        #                        $MobileDevices = Get-MobileDevice -Identity $UserMail -ResultSize unlimited | Where-Object { ($_.ClientType -eq "EAS") -or ($_.DeviceModel -eq "Outlook for iOS and Android") }

                        #                        ForEach ($MobileDevice in $MobileDevices) {
                        #                            Clear-MobileDevice $MobileDevice.Identity -AccountOnly -Confirm:$false
                        #                        }

                        # Mac/Windows etc.
                        #                        $OtherDevices = Get-MobileDevice -Mailbox $UserMail -ResultSize unlimited | Where-Object { ($_.ClientType -ne "EAS") -and ($_.DeviceModel -ne "Outlook for iOS and Android") }
                    
                        #                        ForEach ($OtherDevice in $OtherDevices) {
                        #                            Try {
                        #                                Clear-MobileDevice $OtherDevice.Identity -AccountOnly -Confirm:$false -ErrorAction Stop
                        #                            }
                        #                            Catch {
                        #                                Write-Host "Account-only wipe failed for device $($OtherDevice.DeviceModel) with identity $($OtherDevice.Identity). Blocking device instead." -ForegroundColor Yellow
                        #                                $BlockedDeviceIDs = @($OtherDevice.DeviceID)
                        #                                Set-CASMailbox $UserMail -ActiveSyncBlockedDeviceIDs $BlockedDeviceIDs
                        #                            }
                        #                        }

                        # Convert User's Mailbox to Shared and Set Full Access Delegation
                        if ($ForwardingAddress -eq $null -or $ForwardingAddress.Length -eq 0) {
                            # Do this
                            Set-Mailbox -Identity $UserMail -Type Shared
                        }
                        else {
                            # Do the forwarding
                            Set-Mailbox -Identity $UserMail -Type Shared
                            Add-MailboxPermission -Identity $UserMail -User $FullAccessAddress -AccessRights FullAccess -InheritanceType All
                        }

                        # Remove Microsoft Licensing
                        $mguser = Get-MgUser -UserId $UserMail -ErrorAction SilentlyContinue
                        if (($mguser)) {
                            try {
                                $SKUs = @(Get-MgUserLicenseDetail -UserId $mguser.id)
                                if (!$SKUs) {
                                    Write-Host "No Licenses found for user $UserMail, skipping..."
                                }
                                foreach ($SKU in $SKUs) {
                                    Write-Host "Removing license $($SKU.SkuPartNumber) from user $UserMail"
                                    try {
                                        Set-MgUserLicense -UserId $mguser.id -AddLicenses @() -RemoveLicenses $Sku.SkuId -ErrorAction Stop #-WhatIf
                                    }
                                    catch {
                                        if ($_.Exception.Message -eq "User license is inherited from a group membership and it cannot be removed directly from the user.") {
                                            Write-Host "License $($SKU.SkuPartNumber) is assigned via the group-based licensing feature, either remove the user from the group or unassign the group license, as needed."
                                        }
                                        else { $_ | Format-List * -Force } #catch-all for any unhandled errors
                                    }
                                }
                            }
                            catch {
                                Write-Host "An error occurred: $($_.Exception.Message)"
                            }
                        }
                        else {
                            Write-Host "User $UserMail not found in 365 Admin. Please verify license removal in portal."
                        }

                        # Remove User from 365 Groups
                        $mguser = Get-MgUser -UserId $UserMail -ErrorAction SilentlyContinue
                        if (($mguser)) {
                            try {
                                $msgroupMemberships = @(Get-MgUserMemberof -UserId $mguser.id)
                                if (!$msgroupMemberships) {
                                    Write-Host "No groups found for user $UserMail, skipping..."
                                }
                                foreach ($group in $msgroupMemberships) {
                                    try {
                                        Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $mguser.id -Confirm:$false
                                        Write-Host "User removed from group: $($group.DisplayName)"
                                    }
                                    catch {
                                        $_ | Format-List * -Force #catch-all for any unhandled errors
                                    }
                                }
                            }
                            catch {
                                Write-Host "An error occurred: $($_.Exception.Message)"
                            }
                        }
                        else {
                            Write-Host "User $UserMail not found in 365 Admin.  Please verify group removal in portal."
                        }
                    }
                    $OffboardingComplete = $True
                }
                elseif ($confirmation -eq "N") {
                    continue
                }
            }
            default {
                $Wrong = @'
    !!!!!!7777777777777777777777777777777!77!!!!?JJJYYYJ7!~~!!~!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!777??JJJYYY555555
    !!!!!!!!77777777777777777777777!~~~^^^^~!!!!????JJJYYYJ!7?!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!777??JJYYYY555555
    !!!!!!!!777777777777777777777!^:.:^^:.:^~!?7!77!!?????!!!7!7J7!~!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!777??JJYYY5555555
    !!!!!!!77777777777777777777!^:^7YGBBGPJ!~^~~!!~~~~!???!^~~^~Y#GY7~!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!777??JJYYY5555555
    !!!!!!777777777777777777777~~YG######&#G57^^^^^^^~7???7!~^~~~G&&#57!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!777??JJYYY555555P
    !!!!!77777777777777777777?5GB##BBB#######BY~:^77!!7?????7~!!7P###&#G?!!!!!!!!!!!!!!!!!!!!!!!!!!!!777??JJYYY55555PP
    !!777777777777777777777?PB#BBBBBBB#B#######PJ~~7!~~777777~!~!5#####&#G?!!!!!!!!!!!!!!!!!!!!!!!!!7777??JJYYY5555PPP
    7777777777777777777777YBBBBBBBBBBB#BBBBBBBBBGJ~^!!!~!777!~!~~JBBB####&#5!!!!!!!!!!!!!!!!!!!!!!!!777???JJYY55555PPP
    777777777777777777777JBBBBBBBBBBBBBBBBBBBGGGBBJ~^~~^^^^^~^~~^!PBB#####&&G7!!!!!!!!!!!!!!!!!!!!!!777???JJYY55555PPP
    77777777777777777777?GBBGBBBBGBBBBBBBBBBGGGGBBB?::^^^^^^~~~~^~YB########&G!!!!!!!!!!!!!!!!!!!!!7777??JJJYY5555PPPP
    77777777777777777777PBBBBGGGBBBGGGBBBBBBBBBBB##P7^:^^:^^^^^:::7GB########&5!!!!!!!!!!!!!!!!!!!!7777??JJJYY5555PPPP
    7777777777777777777?GGGGGGGGGBBGGGGGBBBB#BBBB###P7:.:^::^^:~~~7PBBB########?!!!!!!!!!!!!!!!!!!!7777???JJYY5555PPPP
    7777777777777777777JGGGGGGGGGGGGGGGGBBBBBBBBGGGGBP7^^~~~~~^~~7?GGBBB###&&###P5YJ?7!!~!~~!!!!!!!!777???JJYY5555PPPP
    7777777777777777777YGGGPPGGGGGGGGGGBBBB####BBGPPPP5~:^~~^^^^~!?GBBGGGGGB#####&####BGPPJ7?Y!!!!!!7777??JJYYY555PPPP
    77777777777777JYJY5PGPPPPGGGGGGGGGGGBB##BBGGGGGBGP5!::^~~~^~!7?J??777?Y5PG###BB#######&##GJ?!!!!!!77???JJYY555PPPP
    7777!7?J555PBB##BBBGPPPPPPGGGGGGGGGGGGGG5J7!!77?7!~~!77?Y?:!7PP~::^^~7?YPPP##55PGPGGGBBB####BGPJ77!77??JJYY555PPPP
    77??5GB#########BP55PPP5PPPGGGGGGGGPYJJYYJ?!!~::..::~7?JYY^~?5?^!!^^~?^^!YYG#B55PPPPPGBBBBB##&####BP77??JJY555PPPP
    7JPG######BBBGBBG5!~Y55PPPPGGGGGGG5YJJ?!^~7~:::^::^~^^^^^~^^~!!!7?77?YPP5JYPBBYY55555GBGGGGGGGB###&#GBGJ?JYY55PPPP
    B#####BBBBGPP5YY5!~~7555P5PGPPPPPP5Y?7!7?55Y?77!!!77!~!!!777?J????JY5PGBBGGGBB?JY55PPGGPPPPBBGBBBBBBBB#BBBBYY55PPP
    &&#####BGGPP5Y?77JY5J7J55PPPPPPPPPPP5PGGGP5YYJJJYYJ7~7??!JJ77J?77J?JYYYGBBB###Y7?J555PPPGGBBBBBBBBBBB######BGGPPPP
    &&&####BBBGP5YY7~75GP!^YPPPPP5PPPGBBBBBGGGPPPPPYYJJ!~!??~7557^7P5?7J~:^YBB###BJ7!?YJY5GGGGGGBBBB##B###BBB#######BP
    &#####BBBBGGP5Y?7~!~~!!^7YPP555PPGGBBBBBBBBBBP5J^:..~!PJ:^YBP^:JG5:!5Y7JPB###B7?^!!7?Y555PPGPGGB#####BB##BBBB##BB#
    &####BBBBGGGGPJ?7~^:~!?7!^~?J555PPPPGGGBBBBG5YP^.:!7^YG?.~~5G!.^5P! ~Y57!75BGJ7?^~~~!7JJY5PPPGGB#BBB##########BGGB
    ####BB#BBBBGP5J7!^^~~!!!!7!~^~?Y5555PPGGGGP55B?:!??^.?57.:^YGJ..7PY..!Y!..^YY!??~^~~77!7?Y55GGGBBGGBBB########BGPP
    ##&&##B##BBGGPY7~^^~~~!~~~~!!~^^!7JYY55555YJGY:~~:. .?P?...!J7..:7?..:!7:.:!P5?7~^^~~~!77J5PPPPPGGGBGGGBBB#####BBP
    &&&#####BBBGGP5?^::^^~~~~~~~~~~~~^^^~!!777!PB::~^. .:^!~^:.^^^..::^.::^^:..^JGY^^:^^^~~!?JYYYY5PPGBBBBBBBB###BBGPP
    &&&#####BBBBPYY?^..:^^^~~~~^^^~~~~~~^^^^^^J#7 ~!~...:..:::.:::::::^:.....:.^!JPJ^::^~!7!7!7??J555PGGGBBGBGPPGGPPPP
    &&&#####BBGGP5J7^...::^^^^^^^^^~^^~^~^^^^!BP..!!^..... ...:.....::::::.:~::^~~.7J^^^^~!!!!7???JYY5PPGBGBBGGP5J555P
    ##########BBGPY7^:....:^^^^^^^^^..:~^^^^^YB^ ^7~^.::....:::.........^~~~~^:..:^^^^:::^~^~7777YYY555PPPPGPGBBGY555P
    &&&&#####BBBBPYJ!^:...^::^^:^^^^^.:55J7!7G? ..::::.^:.~7~^:.:^:.^!~..^JP57~::^^^^:::::::^~!!?JJYYY55555P5PGBGYY55P
    #########BBGP5YY?~:......::^::^^^:.~J555J7:^:....... ^BP5! .77~.~JJ!..^JY?7~::^^^^::::::^~!!7777?JYYY55PPPGG5YY55P
    &#######BBBGP5YYJ7^:.......:::^^::::^~7?7^^!^:.::....?5JY: .?5!  :J57:::::~~^~^~~~^^::::^~^~~~!????JYYJJ5PG5JYY55P
    &&&&####BBBBGPYJJ7^:..... ...::^^:::::::^^::::..^^:.^~~^....YP?...~JY7^!^:^??^^~^^^^^:^::^^~~~7??JJ?YJ?!?5P5JJY555
    &&&&&######BGPPYJ?!:........ ...::^^:::::::::..:~~~.:::^:..:!7~::.:^!!^!::^7JJ~^::::^^::::^~~~~!?5J7JY5Y5PJ?JJY555
    &&&&#####BBGGPPY???~:........:!!^:::::::::::::^?57~^:^^^::::~^^::..^~~::.:~~:~7?:::::::::::::::^?J7?YJ??Y5???JYY55
    &&&#####BBBBP55YJ?7~:........:7?J?7~^..::::::^YB5!^.:~^^::..::::^:...::.:.:. :^:::::^^^:::..:::^7?7YYYYJ?!!??JJY55
    ##&&####BBBBGPP5YJ?^..........7???JJ?7~::...^PP7..:.:^:::.:..:::::::::^:.::.:^:::^^:::::::::::::^??5J?JJJ?77?JJYY5
    &&#####BBBGGGGP5YJ?7:........^~7??????77~^:..^~:  ..::....::::::::::::::^~:::........   ....:^^~~7?J5YJ7?Y?7??JYY5
    &###BBGGGGGBBBGGPJJ?::::...:^~~!7?????777!~~^^^:. .::::..............::^~77?~.   ........   .?P5555J5YJ?7?777?JJYY
    &&###BBBGGGB#BGG55Y?^....:^~~~!!!7????????7!!~^^::::::......::::::^^~~~!777?!^:  .  .....    ^BBG5YY5J?JY??????JYY
    BBGGGBBBB#BBBP55YJY7:.::^^~!!!!!!77??????J??77~~^^^::::::::^^^^^^^~~~!!!77??!^:. .         . .J5Y555PPYJY?JY5PP5YY

    Oh, you think Powershell is your ally, But you merely adopted Powershell. I was born with it, molded by it.
    I didn't see the GUI until I was already a man, by then it was nothing to me but blinding!
    The scripts betray you because they belong to me.
'@
                Write-Host $Wrong
                Write-Host ""
            }
        }
    
    }
    catch {
        Write-Host "Oops, something didn't work:
                   $($_.Exception.Message)
                   "
        Write-Host "Try Again."
        $OffboardingComplete = $False
    }
}

# script completed successfully
Write-Host "Yay, the script actually worked."
Write-Host "Press any key to exit..."

# exit PowerShell
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
exit