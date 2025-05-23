# Connect to Microsoft Graph with the necessary permissions
Connect-MgGraph -Scopes "Application.ReadWrite.All"

function Get-InputCsv {
    do {
        Write-Host "The CSV file must contain a single column named 'applicationID'. Press Enter to continue."
        [void][System.Console]::ReadLine()

        $inputCsv = Read-Host "Enter the full file path to the import CSV file"
        if (-not (Test-Path -Path $inputCsv -PathType Leaf)) {
            Write-Host "Invalid file path. Please enter a valid file path."
        }
    } while (-not (Test-Path -Path $inputCsv -PathType Leaf))
    return $inputCsv
}

# Path to the CSV file
$inputCsv = Get-InputCsv

# Import the CSV file
$apps = Import-Csv -Path $inputCsv

# Security group ID to be added
$securityGroupId = "your-security-group-id"

# Loop through each application and add the security group
foreach ($app in $apps) {
    $appId = $app.ApplicationId
    Add-MgApplicationOwner -ApplicationId $appId -OwnerId $securityGroupId
}

Write-Host "Security group added to all applications successfully."
