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
    "No",
    "Nope",
    "Nuh Uh"
)

function ShowNedry {
    Write-Host "*Insert Nedry wagging his finger*"
    # Repeat the quote every 2 seconds infinitely
    while ($true) {
        Write-Host "Ah Ah Ah, you didn't say the magic word!"
        Start-Sleep -Seconds 2
    }
}

# Randomly select the correct answer for the first question
$Affirmative01 = $yesanswers | Get-Random

# Ask "Are you sure?" question
$confirmationResponse = Read-Host "Are you sure you want to proceed with Single User Deletion? ($Affirmative01/No)"

# Check if the confirmation response matches the correct answer
if ($confirmationResponse -eq $Affirmative01) {
    # User provided the correct answer for the first question, proceed to ask "Are you sure?" question

    # Randomly select a new answer for the "Are you sure?" question
    $Affirmative02 = ($yesanswers | Where-Object {$_ -ne $Affirmative01}) | Get-Random

    # "Are You Really Sure?"
    $confirmationResponse = Read-Host "Are you ABSOLUTELY 100% sure you want to proceed? IT IS A ROYAL PITA TO REVERSE THIS. ($Affirmative02/No)"

    # Check if the confirmation response matches the answer
    if ($confirmationResponse -eq $Affirmative02) {
        # User provided the correct answer for the "Are you sure?" question, proceed to ask next question

        # Randomly select a new answer for the "Really?" question
        $Affirmative03 = ($yesanswers | Where-Object {$_ -notin @($Affirmative01, $Affirmative02)}) | Get-Random

        # "Are You Absolutely Sure?"
        $confirmationResponse = Read-Host "Seriously, please double check that this is the correct script you want to run. Do you really want to SMITE A USER FROM EXISTENCE? ($Affirmative03/No)"

        # Check if the confirmation response matches the answer
        if ($confirmationResponse -eq $Affirmative03) {
            # User provided the correct answer for the "Really?" question, proceed accordingly

            # Add your code here for handling the final correct answer
            
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

# Script completed successfully
Write-Host "Yay, the script actually worked."
Write-Host "Press any key to exit..."
