<#
.SYNOPSIS
    This script initiate the onboarding and offboarding of Litera employee.
.DESCRIPTION
    This is a Function based programing. It helps multiple team to collaborate and make changes as required. Main.PS1 is entry place for Scripts and call Functions
.NOTES
   To improve the capability you can add function under the Functions folder and import fuctions to Main PS1.
.LINK
    Specify a URI to a help page, this will show when Get-Help -Online is used.
.EXAMPLE
    Test-MyTestFunction -Verbose
    Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
#>

. .\Functions\banner.ps1
. .\Functions\DA_Cred.ps1
. .\Functions\PasswordGenerator.ps1
. .\Functions\onboarding_func.ps1
. .\Functions\offboarding.ps1
. .\Functions\onboarding.ps1
. .\Functions\menu.ps1
. .\Functions\Get_LiteraModule.ps1


clear-Host
Get-LiteraModule
Show-LiteraBanner
Write-Host -NoNewLine ' Press any key to continue...'
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
Select-LiteraMainMenu