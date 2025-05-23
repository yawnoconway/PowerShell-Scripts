# Log in to Azure
Connect-AzAccount

# Create a new Excel package
New-Object -TypeName OfficeOpenXml.ExcelPackage
$excelFilePath = "PATH\TO\XLSX\AzureSubscriptionsData.xlsx"

Import-Csv -Path "PATH\TO\CSV\subscriptions.csv" | ForEach-Object {
    $SubID = ($_.SubscriptionId)

    # Set the context to the subscription
    Set-AzContext -SubscriptionId $SubID

    # Get cost information (this requires the right permissions and configuration)
    # Note: Azure Cost Management APIs might be needed, or you can use the
    # `Get-AzConsumptionUsageDetail` cmdlet for simplified cost data.
    #$costs = Get-AzConsumptionUsageDetail

    # Get all resources in the subscription
    $resources = Get-AzResource

    # Export cost information to a worksheet in the Excel workbook
    #$costWorksheetName = "Costs_Subscription_$($SubID)"
    #$costs | Export-Excel -Path $excelFilePath -WorksheetName $costWorksheetName -AutoSize -AutoFilter -FreezeTopRow

    # Export resources to a separate worksheet in the Excel workbook
    $resourceWorksheetName = "Resources_Subscription_$($SubID)"
    $resources | Select-Object Name, ResourceType, ResourceGroupName, Location, ResourceId |
        Export-Excel -Path $excelFilePath -WorksheetName $resourceWorksheetName -AutoSize -AutoFilter -FreezeTopRow
}

Write-Host "Data has been exported to $excelFilePath"
