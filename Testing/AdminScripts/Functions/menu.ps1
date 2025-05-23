
function Show-LiteraMainMenu {
    [CmdletBinding()]
    param (
        
    )
    
    begin { Clear-Host
        Show-LiteraBanner
        
    }
    
    process {
        Write-host "Select the Options from the Menu" -ForegroundColor Yellow  `n


        Write-host " > ONBOARDING:  Select '1'" -ForegroundColor Blue
        Write-host " > OFFBOARDING: Select '2'" -ForegroundColor Blue
        Write-host " > QUIT:        Select 'q' " -ForegroundColor Blue
    }

    
    end {
    }
}




function Select-LiteraMainMenu {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        
    }
    
    process {
        
        do{ 

            Show-LiteramainMenu

            $user_input = Read-Host "`n `n Please Make a Selection"
                switch ($user_input) {
                    '1' { Clear-Host
                        Select-LiteraOnboardingMenu }
                    '2' {Clear-Host
                         Get-LiteraOffboarding}
                    'q' {exit}
                }
                Pause
            }
            until ($user_input -eq 'q' -or $user_input -eq '1' -or $user_input -eq '2' )
            
        
    }
    
    end {
        
    }
}

function Show-LiteraOnboardingMenu {
    [CmdletBinding()]
    param (
        
    )
    
    begin { Clear-Host 
        Show-LiteraBanner
        
    }
    
    process {
        Write-host "Select the Options from the Menu" -ForegroundColor Yellow  `n
        Write-host " > MANUAL ONBOARDING:   Select '1'" -ForegroundColor Blue
        Write-host " > CSV FILE:            Select '2'" -ForegroundColor Blue
        Write-host " > PROD ACCOUNT:        Select '3'" -ForegroundColor Blue
        Write-host " > LMS-CloudLab:        Select '4'" -ForegroundColor Blue
        Write-host " < Main Menu:           Select '5'" -ForegroundColor Blue `n
    }
    
    end {
    }
}

function Select-LiteraOnboardingMenu {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        
    }
    
    process {
        
        do{
            Show-LiteraOnboardingMenu
            $user_input = Read-Host "`n `n Please Make a Selection"
                switch ($user_input) {
                    '1' { Clear-Host
                        Get-literaonboarding_Manual }
                    '2' {Clear-Host
                        Get-literaonboarding_withCSVfile  }
                    '3' { Clear-Host
                        Get-literaonboarding_ProdAccount }
                    '4' {Clear-Host
                        Get-Literaonboarding_LMSCloudlab}
                    '5' {Select-LiteraMainMenu }
                }
                Pause
            }
            until ($user_input -eq '1' -or $user_input -eq '2' -or $user_input -eq '3' -or $user_input -eq '4' -or $user_input -eq '5')      
    }
    
    end {
        
    }
}