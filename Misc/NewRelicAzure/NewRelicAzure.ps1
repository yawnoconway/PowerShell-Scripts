<#
.SYNOPSIS
    Create Terraform files from a template and a CSV file in a specified directory.
.DESCRIPTION
    This script reads a template file and a CSV file, replaces placeholders in the template with values from the CSV,
    and creates Terraform files in a new directory named after the tenant_id extracted from the template.
    If the directory already exists, it will be deleted before creating a new one.
    The script requires PowerShell and appropriate permissions to create directories and files.
.NOTES
    Version: 1.5
    Updated: June 16, 2025
    Author: Josh Conway
    Previous: N/A
    Changelog:
        1.5 - Will now create a new folder based on the tenant_id variable in the template
        1.0 - Initial version
#>

# Load the template file
$template = Get-Content "$PSScriptRoot\template.txt" -Raw

# Extract tenant_id from the template
$tenant_id = [regex]::match($template, 'tenant_id = "(.*?)"').Groups[1].Value

# Check if the folder exists
if (Test-Path "$PSScriptRoot\$tenant_id") {
    # Delete the folder
    Remove-Item -Path "$PSScriptRoot\$tenant_id" -Recurse -Force
}

# Create a new folder named as tenant_id
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\$tenant_id"

# Load the CSV file
$csv = Import-Csv "$PSScriptRoot\input.csv"

# Loop through each row in the CSV file
foreach ($row in $csv) {
    # Replace the placeholders in the template with the data from the current row
    $output = $template -f $row.Name, $row.SubscriptionId

    # Specify the path to the output file
    # This example creates a new file for each row, with the filename based on the first column
    $outputFile = "$PSScriptRoot\$tenant_id\{0}.txt" -f $row.Name

    # Write the output to the file
    $output | Set-Content $outputFile
}

# Get all .txt files in the directory
Get-ChildItem -Path "$PSScriptRoot\$tenant_id" -Filter *.txt | ForEach-Object {
    # Rename the file, changing the extension to .tf
    Rename-Item -Path $_.FullName -NewName ($_.BaseName + ".tf")
}