# Changelog
# 1.0 - Initial version

# Import the Active Directory module
if (!(Get-Module ActiveDirectory -ListAvailable -ErrorAction SilentlyContinue)) {
    Import-Module ActiveDirectory
}
# Import the Exchange Online module
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
Connect-Graph -Scopes User.ReadWrite.All, Organization.Read.All

$banner = @'
    __    _ __                                                                         
   / /   (_) /____  _________ _                                                        
  / /   / / __/ _ \/ ___/ __ `/                                                        
 / /___/ / /_/  __/ /  / /_/ /                                                         
/_____/_/\__/\___/_/   \__,_/__       __     __  _                     ___   ____ 
  / / / /_______  _____   / __ \___  / /__  / /_(_)___  ____          <  /  / __ \
 / / / / ___/ _ \/ ___/  / / / / _ \/ / _ \/ __/ / __ \/ __ \    _  _ / /  / / / /
/ /_/ (__  )  __/ /     / /_/ /  __/ /  __/ /_/ / /_/ / / / /   | |/ / /_ / /_/ / 
\____/____/\___/_/     /_____/\___/_/\___/\__/_/\____/_/ /_/    |___/_/(_)\____/  
                                                                                       
'@
Write-Host $banner -ForegroundColor Yellow
Write-Host "This script will do the following in this order:

           1. Convert shared mailbox to a 'full' mailbox
           2. Remove all licenses from the user.
           3. Delete the user from AD
           " -ForegroundColor Cyan

# List of possible answers
$yesanswers = @(
    "Yes",
    "Yaaas",
    "Y",
    "Punch it",
    "Yeah",
    "Sure",
    "Definitely",
    "Roger Roger",
    "Lets-a-Go"
)
$noanswers = @(
    "No",
    "Nah",
    "Negative",
    "Nope",
    "Nuh Uh",
    "N",
    "Negatory",
    "LOL",
    "Never"
)

function ShowNedry {
    Write-Host "*Insert Nedry wagging his finger*"
    # Repeat the quote every 2 seconds infinitely
    while ($true) {
        Write-Host "Ah Ah Ah, you didn't say the magic word!"
        Start-Sleep -Seconds 2
    }
}

$DeletionComplete = $False
while ($DeletionComplete -eq $False) {
    try {
        $answer = Read-Host "Are you deleting a single user, or in bulk? (Single/Bulk)"

        switch ($answer) {
            "Single" {                
                # Randomly select the correct answer for the first question
                $Affirmative01 = $yesanswers | Get-Random

                # Ask "Are you sure?" question
                $confirmationResponse = Read-Host "Are you sure you want to proceed with Single User Deletion? ($Affirmative01/No)"

                # Check if the confirmation response matches the correct answer
                if ($confirmationResponse -eq $Affirmative01) {
                    # User provided the correct answer for the first question, proceed to ask "Are you absolutely sure?" question

                    # Randomly select a new answer for the "Are you absolutely sure?" question
                    $Affirmative02 = ($yesanswers | Where-Object { $_ -ne $Affirmative01 }) | Get-Random

                    # Ask "Are you absolutely sure?" question
                    $confirmationResponse = Read-Host "Are you ABSOLUTELY 100% sure you want to proceed? IT IS A ROYAL PITA TO REVERSE THIS. ($Affirmative02/No)"

                    # Check if the confirmation response matches the "Are you absolutely sure?" answer
                    if ($confirmationResponse -eq $Affirmative02) {
                        # User provided the correct answer for the "Are you absolutely sure?" question, proceed to ask "Seriously?" question

                        # Randomly select a new answer for the "Seriously?" question
                        $Affirmative03 = ($yesanswers | Where-Object { $_ -notin @($Affirmative01, $Affirmative02) }) | Get-Random

                        # Ask "Seriously?" question
                        $confirmationResponse = Read-Host "Seriously, please double check that this is the correct script you want to run. Do you really want to SMITE A USER FROM EXISTENCE? ($Affirmative03/No)"

                        # Check if the confirmation response matches the "Seriously?" answer
                        if ($confirmationResponse -eq $Affirmative03) {
                            # User provided the correct answer for the "Seriously?" question, proceed accordingly

                            # Set the variables, and perform deletion steps
                            $Username = Read-Host "Enter the username of the employee to be deleted"
#                            $UserSAM = ($Username -replace '(?<=(.{20})).+')
                            $UserMail = ($Username + "@litera.com")

                            # Convert the user's mailbox to a full mailbox
#                            try {
#                                Set-Mailbox -Identity $UserMail -Type Regular
#                            }
#                            catch {
#                                Write-Host "An error occurred: $($_.Exception.Message)"
#                            }
                            
                            # Remove Microsoft Licensing
                            try { $user = Get-MgUser -UserId $UserMail -ErrorAction Stop }
                            catch { Write-Verbose "User $UserMail not found, skipping..." ; continue }
                         
                            $SKUs = @(Get-MgUserLicenseDetail -UserId $user.id)
                            if (!$SKUs) { Write-Verbose "No Licenses found for user $UserMail, skipping..." ; continue }
                         
                            foreach ($SKU in $SKUs) {
                                Write-Verbose "Removing license $($SKU.SkuPartNumber) from user $UserMail"
                                try {
                                    Set-MgUserLicense -UserId $user.id -AddLicenses @() -RemoveLicenses $Sku.SkuId -ErrorAction Stop #-WhatIf
                                }
                                catch {
                                    if ($_.Exception.Message -eq "User license is inherited from a group membership and it cannot be removed directly from the user.") {
                                        Write-Verbose "License $($SKU.SkuPartNumber) is assigned via the group-based licensing feature, either remove the user from the group or unassign the group license, as needed."
                                        continue
                                    }
                                    else { $_ | Format-List * -Force; continue } #catch-all for any unhandled errors
                                }
                            }
                            # Delete the user's account in Active Directory
#                            Remove-ADUser -Identity $UserSAM -Confirm:$false

                            $DeletionComplete = $True            
                        }
                        elseif ($confirmationResponse -in $noanswers) {
                            # User wants to exit the script
                            continue
                        }        
                        else {
                            # User didn't confirm with the correct answer for the "Seriously?" question, go into infinite loop
                            ShowNedry
                        }
                    }
                    elseif ($confirmationResponse -in $noanswers) {
                        # User wants to exit the script
                        continue
                    }    
                    else {
                        # User didn't confirm with the correct answer for the "Are you absolutely sure?" question, go into infinite loop
                        ShowNedry
                    }
                }
                elseif ($confirmationResponse -in $noanswers) {
                    # User wants to exit the script
                    continue
                }
                else {
                    # User didn't confirm with the correct answer for the first question, go into infinite loop
                    ShowNedry
                }            
            }
            "Bulk" {
                # Randomly select the correct answer for the first question
                $Affirmative01 = $yesanswers | Get-Random

                # Ask "Are you sure?" question
                $confirmationResponse = Read-Host "Are you sure you want to proceed with Bulk User Deletion? ($Affirmative01/No)"

                # Check if the confirmation response matches the correct answer
                if ($confirmationResponse -eq $Affirmative01) {
                    # User provided the correct answer for the first question, proceed to ask "Are you sure?" question

                    # Randomly select a new answer for the "Are you sure?" question
                    $Affirmative02 = ($yesanswers | Where-Object { $_ -ne $Affirmative01 }) | Get-Random

                    # Ask "Are You Really Sure?" question
                    $confirmationResponse = Read-Host "Are you ABSOLUTELY 100% sure you want to proceed? IT IS A ROYAL PITA TO REVERSE THIS. ($Affirmative02/N)"

                    # Check if the confirmation response matches the "Are you sure?" answer
                    if ($confirmationResponse -eq $Affirmative02) {
                        # User provided the correct answer for the "Are you sure?" question, proceed to ask "Really?" question

                        # Randomly select a new answer for the "Really?" question
                        $Affirmative03 = ($yesanswers | Where-Object { $_ -notin @($Affirmative01, $Affirmative02) }) | Get-Random

                        # Ask "Are You Absolutely Sure?" question
                        $confirmationResponse = Read-Host "Seriously, please double check that this is the correct script you want to run. Do you really want to SMITE A USER FROM EXISTENCE? ($Affirmative03/N)"

                        # Check if the confirmation response matches the "Really?" answer
                        if ($confirmationResponse -eq $Affirmative03) {
                            # User provided the correct answer for the "Really?" question, proceed accordingly

                            # Import the CSV file, set the variables, and perform deletion steps 
                            Import-Csv -Path C:\Users\Public\Documents\BulkDeletion.csv | ForEach-Object {
                                $Username = ($_.username)
#                                $UserSAM = ($Username -replace '(?<=(.{20})).+')
                                $UserMail = ($Username + "@litera.com")

                                # Convert the user's mailbox to a full mailbox
#                                try {
#                                   Set-Mailbox -Identity $UserMail -Type Regular
#                              }
#                                catch {
#                                    Write-Host "An error occurred: $($_.Exception.Message)"
#                                }
                                
                                # Remove Microsoft Licensing
                                try { $user = Get-MgUser -UserId $UserMail -ErrorAction Stop }
                                catch { Write-Verbose "User $UserMail not found, skipping..." ; continue }
                             
                                $SKUs = @(Get-MgUserLicenseDetail -UserId $user.id)
                                if (!$SKUs) { Write-Verbose "No Licenses found for user $UserMail, skipping..." ; continue }
                             
                                foreach ($SKU in $SKUs) {
                                    Write-Verbose "Removing license $($SKU.SkuPartNumber) from user $UserMail"
                                    try {
                                        Set-MgUserLicense -UserId $user.id -AddLicenses @() -RemoveLicenses $Sku.SkuId -ErrorAction Stop #-WhatIf
                                    }
                                    catch {
                                        if ($_.Exception.Message -eq "User license is inherited from a group membership and it cannot be removed directly from the user.") {
                                            Write-Verbose "License $($SKU.SkuPartNumber) is assigned via the group-based licensing feature, either remove the user from the group or unassign the group license, as needed."
                                            continue
                                        }
                                        else { $_ | Format-List * -Force; continue } #catch-all for any unhandled errors
                                    }
                                }

                                # Delete the user's account in Active Directory
#                                Remove-ADUser -Identity $UserSAM -Confirm:$false
                            }
                            $DeletionComplete = $True            
                        }
                        elseif ($confirmationResponse -in $noanswers) {
                            # User wants to exit the script
                            continue
                        }        
                        else {
                            # User didn't confirm with the correct answer for the "Really?" question, go into infinite loop
                            ShowNedry
                        }
                    }
                    elseif ($confirmationResponse -in $noanswers) {
                        # User wants to exit the script
                        continue
                    }    
                    else {
                        # User didn't confirm with the correct answer for the "Are you sure?" question, go into infinite loop
                        ShowNedry
                    }
                }
                elseif ($confirmationResponse -in $noanswers) {
                    # User wants to exit the script
                    continue
                }
                else {
                    # User didn't confirm with the correct answer for the first question, go into infinite loop
                    ShowNedry
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
        $DeletionComplete = $False
    }
}

# Script completed successfully
Write-Host "Yay, the script actually worked."
Write-Host "Press any key to exit..."

# Exit PowerShell
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
exit