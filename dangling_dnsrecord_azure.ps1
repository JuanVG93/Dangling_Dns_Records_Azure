Function LogonAAD {
	
	#Checking if there's a session active in AzureAD, if no active session then it will log you in
    Write-Host "Checking if you're currently signed into AzureAD" -Foregroundcolor Yellow
	
    if($null -eq $azureConnection.Account) 
    {
		
        Write-Host "You're currently not signed into AzureAD" -Foregroundcolor Red
        $AdminUser = whoami /upn
        Connect-AzureAD -AccountId $AdminUser
        Connect-AzAccount -AccountId $AdminUser
        (Get-AzureADUser -ObjectId $AdminUser).ObjectId

        if ($?) {

            Write-Host "You are now signed into AzureAD! Welcome back $AdminUser" -Foregroundcolor Green

        }
		
    }
		
	else {
		
		Write-Host "You're already signed into AzureAD!" -Foregroundcolor Green
	}
	
}

Function Get-SubscriptionIds {

    Param
    (

        [Parameter(Mandatory = $False)] [String]$DnsZone

    )

    # Cache all Active Subscriptions
	$SubscriptionIds = (Get-AzSubscription | Where-Object {$_.State -eq "Enabled"})

    # Count Active Subscriptions
	$TotalSubscriptions = $SubscriptionIds.Count
	Write-Host "[INFO] $TotalSubscriptions Active Subscriptions found..." -Foregroundcolor Gray


    try {

        # Start looping through all subscription IDs
        ForEach ($ID in $SubscriptionIds.Id) {

            # Get the name of the Subscription
            $SubscriptionName = (Get-AzSubscription -SubscriptionId $ID).Name

            # Set the Context to the current SubscriptionID we're looping through
            Write-Host "[INFO] Searching through subscription: $SubscriptionName" -ForegroundColor Gray
            $SubscriptionContext = Set-AzContext -SubscriptionId $ID 2>$null

            # Cache all Dns Zones within a subscription
            $DnsZones = (Get-AzDnsZone).Name 2>$null

            if (!$DnsZones) {

                Write-Host "[INFO] There are no DNS Zones listed in this subscription!`n" -ForegroundColor Red

            }

            else {

                ForEach ($DnsZone in $DnsZones) {

                    # Gather all Resource Groups within the Subscription if a DNS Zone is found
                    Get-AzureResourceGroupNames -DnsZone $DnsZone

                }

            }

        }

    }
    
    catch {

        Write-Host "`nError Message: " $_.Exception.Message -ForegroundColor Red
		Write-Host "`nError in Line: " $_.InvocationInfo.Line -ForegroundColor Red
		Write-Host "`nError in Line Number: "$_.InvocationInfo.ScriptLineNumber -ForegroundColor Red
		Write-Host "`nError Item Name: "$_.Exception.ItemName -ForegroundColor Red

    }

}

Function Get-AzureResourceGroupNames {

    Param
    (

        [Parameter(Mandatory = $False)] [Array]$ResourceGroupNames,
        [Parameter(Mandatory = $False)] [String]$DnsZone

    )

    # Start with an empty arraylist
    [Array]$ResourceGroupNames = @()

    # Cache all ResourceGroupNames in Azure ensuring no duplicates are returned
    $ResourceGroupNames = (Get-AzResource | Select-Object ResourceGroupName | Sort-Object -Property ResourceGroupName -Unique).ResourceGroupName

    if (!$ResourceGroupNames) {

        Write-Host "[INFO] There are no Resource Groups within this subscription" -ForegroundColor Red

    }

    else {

        # Gather all DNS Records for each Resource Group
        Get-DNSRecordsAzure -ResourceGroupNames $ResourceGroupNames -DnsZone $DnsZone 

    }

}

Function Get-DNSRecordsAzure {

    Param
    (

        [Parameter(Mandatory = $False)] [Array]$ResourceGroupNames,
        [Parameter(Mandatory = $False)] [String]$DnsZone,
        [Parameter(Mandatory = $False)] [String]$DnsRecord

    )

    try {

        # Start looping through all Resource Groups
        ForEach ($ResourceGroupName in $ResourceGroupNames) {

            Write-Host "[INFO] DNS Zone found in Resource Group: $($ResourceGroupName): `n" -ForegroundColor Yellow

            # Cache all DNS Records within the DNS Zone and Resource Group and return the CNAME records
            $DnsRecordSet = Get-AzDnsRecordSet -ZoneName $DnsZone -ResourceGroupName $ResourceGroupName -RecordType CNAME 2>$null

            if (!$DnsRecordSet) {

                Write-Host "[INFO] No DNS Records found for this Resource Group!`n" -ForegroundColor Red

            }

            else {

                Write-Host "[INFO] DNS Records found" -ForegroundColor Yellow

                # Start looping through each DNS Record
                foreach ($DnsRecord in $DnsRecordSet.Records) {

                    Write-Host "[INFO] Attempting to resolve $($DnsRecord)..." -ForegroundColor Yellow

                    # Attempt to resolve the DNS Record
                    Get-DnsResolution -DnsRecord $DnsRecord

                }

            }

        }

    }

    catch {

        Write-Host "`nError Message: " $_.Exception.Message -ForegroundColor Red
		Write-Host "`nError in Line: " $_.InvocationInfo.Line -ForegroundColor Red
		Write-Host "`nError in Line Number: "$_.InvocationInfo.ScriptLineNumber -ForegroundColor Red
		Write-Host "`nError Item Name: "$_.Exception.ItemName -ForegroundColor Red

    }
    

}

Function Get-DnsResolution {

    Param
    (

        [Parameter(Mandatory = $False)] [String]$DnsRecord

    )

    try {

        # Cache the result
        $Result = (Resolve-DnsName -Name $DnsRecord) 2>$null

        if ($Result.Section -eq "Answer") {

            Write-Host "[INFO] DNS Record $DnsRecord resolved" -ForegroundColor Green
            
        }

        else {

            Write-Output $DnsRecord | Out-File "C:\temp\DanglingDnsRecordsAzure.csv"

        }

    }

    catch {

        Write-Host "`nError Message: " $_.Exception.Message -ForegroundColor Red
		Write-Host "`nError in Line: " $_.InvocationInfo.Line -ForegroundColor Red
		Write-Host "`nError in Line Number: "$_.InvocationInfo.ScriptLineNumber -ForegroundColor Red
		Write-Host "`nError Item Name: "$_.Exception.ItemName -ForegroundColor Red

    }

}

Function Main {


    Write-Host "[INFO] This script will enumerate all DNS Zones and list the CNAME records from every Resource Group in Azure across all active subscriptions" -ForegroundColor Yellow

    Get-SubscriptionIds

}

LogonAAD
Main
Write-Host "Done!" -ForegroundColor Green