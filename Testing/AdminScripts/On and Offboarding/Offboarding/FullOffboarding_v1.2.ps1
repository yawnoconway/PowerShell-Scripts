# Changelog
# 1.2 - Will now modify Emp Status and Ext Attr 14 to "Inactive" and cleaned up some formatting
# 1.1 - Added moving to disabled OU, and a list of script functions to the beginning
# 1.0 - Initial version

# Import the Active Directory module
if (!(Get-Module ActiveDirectory -ListAvailable -ErrorAction SilentlyContinue)) {
    Import-Module ActiveDirectory
}

# Import the Exchange Online module and connect if not already
if (!(Get-Module ExchangeOnlineManagement -ListAvailable -ErrorAction SilentlyContinue)) {
    Import-Module ExchangeOnlineManagement
}
#Connect & Login to ExchangeOnline (MFA)
if ((Get-PSSession -Name 'ExchangeOnlineInternalSession*' -ErrorAction SilentlyContinue).Count -eq 0) {
    Connect-ExchangeOnline
}

$banner = @'
    __    _ __                                                             
   / /   (_) /____  _________ _                                            
  / /   / / __/ _ \/ ___/ __ `/                                            
 / /___/ / /_/  __/ /  / /_/ /                                             
/_____/_/\__/\___/_/   \__,_/               ___                     ___
  / __ \/ __/ __/ /_  ____  ____ __________/ (_)___  ____ _        <  /   ___
 / / / / /_/ /_/ __ \/ __ \/ __ `/ ___/ __  / / __ \/ __ `/   _  __/ /   |_  |
/ /_/ / __/ __/ /_/ / /_/ / /_/ / /  / /_/ / / / / / /_/ /   | |/ / /   / __/
\____/_/ /_/ /_.___/\____/\__,_/_/   \__,_/_/_/ /_/\__, /    |___/_/(_)/____/
                                                  /____/

'@
Write-Host $banner
Write-Host "This script will do the following in this order:

           1. Disable AD account
           2. Change password
           3. Modify Emp Status and Ext Attr 14 to 'Inactive'
           4. Remove user from AD groups
           5. Move them to the Disabled Users OU
           6. Hide from GAL
           7. Convert to shared mailbox
           8. Set email forward if specified
           "

$OffboardingComplete = $False
while ($OffboardingComplete -eq $False) {
    try {
        $answer = Read-Host "Are you offboarding a single user, or in bulk? (Single/Bulk)"

        switch ($answer) {
            "Single" {
                # commands to run for single user
                
                # Set the variables, and perform offboarding steps 
                $Username = Read-Host "Enter the username of the employee to be offboarded"
                $ForwardingUser = Read-Host "Enter the username for whom the email will forward to. Leave blank for no forwarding"
                $UserSAM = ($Username -replace '(?<=(.{20})).+')
                $UserMail = ($Username + "@litera.com")
                $Password = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 20 | ForEach-Object { [char]$_ })
                $ForwardingAddress = ($ForwardingUser + "@litera.com")

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
                Set-ADUser -Identity $UserSAM -Replace @{empstatus = 'Inactive' }
                Set-ADUser -Identity $UserSAM -Replace @{extensionAttribute14 = 'Inactive' }
                Get-ADPrincipalGroupMembership $UserSAM | ForEach-Object { if (($_.name -ne "Domain Users") -and ($_.name -notlike "group_*")) { Remove-ADGroupMember -Identity $_ -Members $UserSAM -Confirm:$false } }
                Move-ADObject -Identity (Get-ADUser -Filter { sAMAccountName -eq $UserSAM }).DistinguishedName -TargetPath "OU=Disabled,OU=Users,OU=LiteraMS,DC=literams,DC=net"

                # Hide the user from the GAL in Local Exchange via AD
                Get-ADuser -Identity $UserSAM -property msExchHideFromAddressLists |  
                Set-ADObject -Replace @{msExchHideFromAddressLists = $true } 

                # Convert the user's mailbox to a shared mailbox and set the forwarding to the manager
                if ($null -eq $ForwardingUser -or $ForwardingUser.Length -eq 0) {
                    # Do this
                    Set-Mailbox -Identity $UserMail -Type Shared
                }
                else {
                    # Do the forwarding
                    Set-Mailbox -Identity $UserMail -Type Shared
                    #                   Set-Mailbox -Identity $UserMail -ForwardingAddress $ForwardingAddress
                }
                $OffboardingComplete = $True
            }
            "Bulk" {
                $confirmation = Read-Host "Are you sure you want to proceed with Bulk User offboarding? (Y/N)"
                if ($confirmation -eq "Y") {
                    # commands to run for bulk users

                    # Import the CSV file, set the variables, and perform offboarding steps 
                    Import-Csv -Path C:\Users\Public\Documents\BulkOffboarding.csv | ForEach-Object {
                        $Username = ($_.username)
                        $UserSAM = ($Username -replace '(?<=(.{20})).+')
                        $UserMail = ($Username + "@litera.com")
                        $Password = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 20 | ForEach-Object { [char]$_ })
                        $ForwardingAddress = $($_.ForwardingAddress)

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
                        Set-ADUser -Identity $UserSAM -Replace @{empstatus = 'Inactive' }
                        Set-ADUser -Identity $UserSAM -Replace @{extensionAttribute14 = 'Inactive' }
                        Get-ADPrincipalGroupMembership $UserSAM | ForEach-Object { if (($_.name -ne "Domain Users") -and ($_.name -notlike "group_*")) { Remove-ADGroupMember -Identity $_ -Members $UserSAM -Confirm:$false } }
                        Move-ADObject -Identity (Get-ADUser -Filter { sAMAccountName -eq $UserSAM }).DistinguishedName -TargetPath "OU=Disabled,OU=Users,OU=LiteraMS,DC=literams,DC=net"

                        # Hide the user from the GAL in Local Exchange via AD
                        Get-ADuser -Identity $UserSAM -property msExchHideFromAddressLists |  
                        Set-ADObject -Replace @{msExchHideFromAddressLists = $true }

                        # Convert the user's mailbox to a shared mailbox and set the forwarding to the manager
                        if ($ForwardingAddress -eq $null -or $ForwardingAddress.Length -eq 0) {
                            # Do this
                            Set-Mailbox -Identity $UserMail -Type Shared
                        }
                        else {
                            # Do the forwarding
                            Set-Mailbox -Identity $UserMail -Type Shared
                            #                   Set-Mailbox -Identity $UserMail -ForwardingAddress $ForwardingAddress
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