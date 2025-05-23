Connect-AzAccount

$Subscription = Get-AzSubscription | Out-GridView -Title 'Select subscription' -OutputMode 'Multiple'

# Initialise output array
$Output = @()

if($Subscription){
    foreach ($item in $Subscription)
    {
        $item | Select-AzSubscription

        # Collect all the resources or resource groups (comment one of below)
        $Resource = Get-AzResource
        #$Resource = Get-AzResourceGroup

        # Obtain a unique list of tags for these groups collectively
        $UniqueTags = $Resource.Tags.GetEnumerator().Keys | Get-Unique -AsString | Sort-Object | Select-Object -Unique | Where-Object {$_ -notlike "hidden-*" }

        # Loop through the resource groups
        foreach ($ResourceGroup in $Resource) {
            # Create a new ordered hashtable and add the normal properties first.
            $RGHashtable = New-Object System.Collections.Specialized.OrderedDictionary
            $RGHashtable.Add("Name",$ResourceGroup.ResourceGroupName)
            $RGHashtable.Add("Location",$ResourceGroup.Location)
            $RGHashtable.Add("Id",$ResourceGroup.ResourceId)
            $RGHashtable.Add("ResourceType",$ResourceGroup.ResourceType)

            # Loop through possible tags adding the property if there is one, adding it with a hyphen as it's value if it doesn't.
            if ($ResourceGroup.Tags.Count -ne 0) {
                $UniqueTags | Foreach-Object {
                    if ($ResourceGroup.Tags[$_]) {
                        $RGHashtable.Add("($_) tag",$ResourceGroup.Tags[$_])
                    }
                    else {
                        $RGHashtable.Add("($_) tag","-")
                    }
                }
            }
            else {
                $UniqueTags | Foreach-Object { $RGHashtable.Add("($_) tag","-") }
            }
            

            # Update the output array, adding the ordered hashtable we have created for the ResourceGroup details.
            $Output += New-Object psobject -Property $RGHashtable
        }

        # Sent the final output to CSV
        $Output | Export-Csv -Path "C:\Users\Public\Public Documents" -append -NoClobber -NoTypeInformation -Encoding UTF8 -Force
    }
}
$Output | Out-GridView