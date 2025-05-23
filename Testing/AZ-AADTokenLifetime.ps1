Connect-AzureAD

$policy = New-AzureADPolicy -Definition @('{"TokenLifetimePolicy":{"Version":1,"AccessTokenLifetime":"08:00:00"}}') -DisplayName "GitHubSessionTest" -IsOrganizationDefault $false -Type "TokenLifetimePolicy"
Get-AzureADPolicy -Id $policy.Id

# Get ID of the service principal
$sp = Get-AzureADServicePrincipal -Filter "DisplayName eq 'GitHub Enterprise Managed User (OIDC)'"

# Assign policy to a service principal
Add-AzureADServicePrincipalPolicy -Id $sp.ObjectId -RefObjectId $policy.Id