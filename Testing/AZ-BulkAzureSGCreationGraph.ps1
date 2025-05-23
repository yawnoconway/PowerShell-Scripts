# Authenticate with Microsoft Graph
Connect-MgGraph -Scopes "Group.ReadWrite.All, User.Read.All"

# Read security group details from CSV file
$CSVRecords = Import-Csv "C:\Users\josh.conway\OneDrive - Litera\Documents\BulkAzureSGCreation.csv"
$TotalItems = $CSVRecords.Count
$i = 0

# Iterate groups one by one and create
ForEach ($CSVRecord in $CSVRecords) {
    $GroupName = $CSVRecord."GroupName"
    $GroupDescription = $CSVRecord."GroupDescription"
    # Split owners and members by semi-colon separator (;) and set in array
#    $Owners = If ($CSVRecord."Owners") { $CSVRecord."Owners" -split ';' } Else { $null }
#    $Members = If ($CSVRecord."Members") { $CSVRecord."Members" -split ';' } Else { $null }

    Try {
        $i++
        Write-Progress -Activity "Creating group $GroupName" -Status "$i out of $TotalItems groups completed" -Id 1

        # Create a new security group
        $NewGroupObj = New-MgGroup -DisplayName $GroupName -SecurityEnabled:$true -Description $GroupDescription -MailEnabled:$false -MailNickname "NotSet" -ErrorAction Stop

        # Add owners
#        if ($Owners) {
#            $TotalOwners = $Owners.Count
#            $OW = 0
#            ForEach ($Owner in $Owners) {
#                $OW++
#                Write-Progress -Activity "Adding owner $Owner" -Status "$OW out of $TotalOwners owners completed" -ParentId 1
#                Try {
#                    $UserObj = Get-MgUser -UserId $Owner -ErrorAction Stop
#                    # Add owner to the new group
#                    Add-MgGroupOwner -GroupId $NewGroupObj.Id -DirectoryObjectId $UserObj.Id -ErrorAction Stop
#                }
#                catch {
#                    Write-Host "Error occurred for $Owner" -ForegroundColor Yellow
#                    Write-Host $_ -ForegroundColor Red
#                }
#            }
#        }
#
#       # Add members
#        if ($Members) {
#            $TotalMembers = $Members.Count
#            $m = 0
#            ForEach ($Member in $Members) {
#                $m++
#                Write-Progress -Activity "Adding member $Member" -Status "$m out of $TotalMembers members completed" -ParentId 1
#                Try {
#                    $UserObj = Get-MgUser -UserId $Member -ErrorAction Stop
#                    # Add a member to the new group
#                    Add-MgGroupMember -GroupId $NewGroupObj.Id -DirectoryObjectId $UserObj.Id -ErrorAction Stop
#                }
#                catch {
#                    Write-Host "Error occurred for $Member" -ForegroundColor Yellow
#                    Write-Host $_ -ForegroundColor Red
#                }
#            }
#        }
    }
    catch {
        Write-Host "Error occurred while creating group: $GroupName" -ForegroundColor Yellow
        Write-Host $_ -ForegroundColor Red
    }
}