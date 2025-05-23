#Provide the subscription Id of the subscription where snapshot exists
$sourceSubscriptionId = '358fe4e7-e3af-45d9-92c4-0c6652500a90'

#Provide the name of your resource group where snapshot exists
$sourceResourceGroupName = 'Compare-Server-Lab01'

#Provide the name of the snapshot
$snapshotName = 'WS2016-ST_OsDisk_1_6eff1d3d51f1494a802fe2266c4ce3c7_14March_WinUpd'
$snapshotNewName = 'WS2016-ST_OsDisk_1_6eff1d3d51f1494a802fe2266c4ce3c7_14March_WinUpd-Copy'

#Set the context to the subscription Id where snapshot exists
Select-AzSubscription -SubscriptionId $sourceSubscriptionId

#Get the source snapshot
$snapshot = Get-AzSnapshot -ResourceGroupName $sourceResourceGroupName -Name $snapshotName

#Provide the subscription Id of the subscription where snapshot will be copied to
#If snapshot is copied to the same subscription then you can skip this step
$targetSubscriptionId = 'yourTargetSubscriptionId'

#Name of the resource group where snapshot will be copied to
$targetResourceGroupName = 'yourTargetResourceGroupName'

$tags = @{
    "bu"                     = ""
    "depatment"              = ""
    "product"                = ""
    "environment"            = ""
    "location"               = ""
    "region"                 = ""
    "provisionedby"          = ""
    "owner"                  = ""
    "billing"                = ""
    "schedule"               = ""
    "bcdr"                   = ""
    "customertype"           = ""
    "customername"           = ""
    "dataclasification"      = ""
    "publcnetworkaccess"     = ""
    "creationdate"           = ""
    "reassessdate"           = ""
    "productionbackup"       = ""
    "ext_monitoring_enabled" = ""
    "ext_monitoring_region"  = ""
}
#Set the context to the subscription Id where snapshot will be copied to
#If snapshot is copied to the same subscription then you can skip this step
Select-AzSubscription -SubscriptionId $targetSubscriptionId

#We recommend you to store your snapshots in Standard storage to reduce cost. Please use Standard_ZRS in regions where zone redundant storage (ZRS) is available, otherwise use Standard_LRS
#Please check out the availability of ZRS here: https://docs.microsoft.com/en-us/Az.Storage/common/storage-redundancy-zrs#support-coverage-and-regional-availability
$snapshotConfig = New-AzSnapshotConfig -SourceResourceId $snapshot.Id -Location $snapshot.Location -CreateOption Copy -SkuName Standard_LRS

#Create a new snapshot in the target subscription and resource group
New-AzSnapshot -Snapshot $snapshotConfig -SnapshotName $snapshotNewName -ResourceGroupName $targetResourceGroupName -tags $tags