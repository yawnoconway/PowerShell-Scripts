<#
.SYNOPSIS
    Create multiple mail contacts in Exchange Online from a CSV file.
.DESCRIPTION
    This script reads contact details from a CSV file and creates mail contacts in Exchange Online.
    The CSV file should contain columns for DisplayName, ExternalEmailAddress, FirstName, LastName, and Alias.
    The script requires appropriate permissions to create mail contacts in Exchange Online.
.NOTES
    Version: 1.0
    Updated: June 16, 2025
    Author: Josh Conway
    Previous: N/A
    Changelog:
        1.0 - Initial version
#>

Connect-ExchangeOnline

Import-Csv -Path "BulkContacts.csv" | ForEach-Object {
    New-MailContact -Name $_.DisplayName `
        -ExternalEmailAddress $_.ExternalEmailAddress `
        -FirstName $_.FirstName `
        -LastName $_.LastName `
        -Alias $_.Alias
}