# Sign in to Azure with a specific tenant
$tenantId = '58bf61bf-63a3-40fa-aa99-f8ef3e02d738'
Connect-AzAccount -Tenant $tenantId

# List subscriptions for the current tenant
$subscriptions = Get-AzSubscription

# Display the subscriptions in the console
$subscriptions | Format-Table -Property Id, Name, TenantId, State

# Export to a CSV file
$subscriptions | Export-Csv -Path "C:\Users\josh.conway\Downloads\subscriptions.csv" -NoTypeInformation