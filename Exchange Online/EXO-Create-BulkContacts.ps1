Connect-ExchangeOnline

Import-Csv -Path "BulkContacts.csv" | ForEach-Object {
    New-MailContact -Name $_.DisplayName `
        -ExternalEmailAddress $_.ExternalEmailAddress `
        -FirstName $_.FirstName `
        -LastName $_.LastName `
        -Alias $_.Alias
}