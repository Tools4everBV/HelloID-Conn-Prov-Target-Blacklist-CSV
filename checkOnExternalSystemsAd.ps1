#################################################
# HelloID-Conn-Prov-Target-Blacklist-CSV-Check-On-External-Systems-AD
# Check if fields are unique
# PowerShell V2
#################################################

# Initialize default properties
$a = $account | ConvertFrom-Json;
$aRef = $accountReference | ConvertFrom-Json

# The entitlementContext contains the configuration
# - configuration: The configuration that is set in the Custom PowerShell configuration
$eRef = $entitlementContext | ConvertFrom-Json
$eRef.configuration.CsvPath = "C:\HelloID\blocklistv2.csv"
# Operation is a script parameter which contains the action HelloID wants to perform for this entitlement
# It has one of the following values: "create", "enable", "update", "disable", "delete"
$o = $operation | ConvertFrom-Json

# Set Success to false at start, at the end, only when no error occurs it is set to true
$success = $false

# Initiate empty list for Non Unique Fields
$nonUniqueFields = [System.Collections.Generic.List[PSCustomObject]]::new()

# Define fields to check
$fieldsToCheck = [PSCustomObject]@{
    "userPrincipalName" = [PSCustomObject]@{ # Value returned to HelloID in NonUniqueFields.
        systemFieldName = 'userPrincipalName' # Name of the field in the system itself, to be used in the query to the system.
        accountValue    = $a.userPrincipalName
        keepInSyncWith  = @("mail", "proxyAddresses") # Properties to synchronize with. If this property isn't unique, these properties will also be treated as non-unique.
        crossCheckOn    = @("mail") # Properties to cross-check for uniqueness.
    }
    "mail"              = [PSCustomObject]@{ # Value returned to HelloID in NonUniqueFields.
        systemFieldName = 'mail' # Name of the field in the system itself, to be used in the query to the system.
        accountValue    = $a.mail
        keepInSyncWith  = @("userPrincipalName", "proxyAddresses") # Properties to synchronize with. If this property isn't unique, these properties will also be treated as non-unique.
        crossCheckOn    = @("userPrincipalName") # Properties to cross-check for uniqueness.
    }
    "proxyAddresses"    = [PSCustomObject]@{ # Value returned to HelloID in NonUniqueFields.
        systemFieldName = 'mail' # Name of the field in the system itself, to be used in the query to the system.
        accountValue    = $a.proxyAddresses
        keepInSyncWith  = @("userPrincipalName", "mail") # Properties to synchronize with. If this property isn't unique, these properties will also be treated as non-unique.
        crossCheckOn    = @("userPrincipalName") # Properties to cross-check for uniqueness.
    }
    "sAMAccountName"    = [PSCustomObject]@{ # Value returned to HelloID in NonUniqueFields.
        systemFieldName = 'sAMAccountName' # Name of the field in the system itself, to be used in the query to the system.
        accountValue    = $a.sAMAccountName
        keepInSyncWith  = @("commonName") # Properties to synchronize with. If this property isn't unique, these properties will also be treated as non-unique.
        crossCheckOn    = $null # Properties to cross-check for uniqueness.
    }
    "commonName"        = [PSCustomObject]@{ # Value returned to HelloID in NonUniqueFields.
        systemFieldName = 'cn' # Name of the field in the system itself, to be used in the query to the system.
        accountValue    = $a.commonName
        keepInSyncWith  = @("sAMAccountName") # Properties to synchronize with. If this property isn't unique, these properties will also be treated as non-unique.
        crossCheckOn    = $null # Properties to cross-check for uniqueness.
    }
}

# Define correlation attribute 
$correlationAttribute = "employeeID"

try {
    # Import CSV data
    $actionMessage = "importing data from CSV file at path [$($eRef.configuration.CsvPath)]"

    # Only load CSV file when it exists
    $csvContent = $null
    if (Test-Path $eRef.configuration.CsvPath) {
        $csvContent = Import-Csv -Path $eRef.configuration.CsvPath -Delimiter $eRef.configuration.Delimiter -Encoding $eRef.configuration.Encoding
    }
    else {
        throw "No CSV file found at path [$($eRef.configuration.CsvPath)]."
    }
    
    foreach ($fieldToCheck in $fieldsToCheck.PsObject.Properties | Where-Object { -not[String]::IsNullOrEmpty($_.Value.accountValue) }) {
        foreach ($fieldToCheckAccountValue in $fieldToCheck.Value.accountValue) {
            # Check if attribute value is in CSV file
            $fieldToCheckAccountValue = $fieldToCheckAccountValue -replace '(?i)^smtp:', '' # Remove smtp: prefix for proxyAddresses

            $actionMessage = "querying CSV row where [attributeName] = [$($fieldToCheck.Value.systemFieldName)] AND [attributeValue] = [$($fieldToCheckAccountValue)]"

            # # Custom check for proxyAddresses to deal smtp: prefix
            $csvCurrentRows = $null
            $csvCurrentRows = $csvContent | Where-Object { $_.attributeName -eq $fieldToCheck.Value.systemFieldName -and $_.attributeValue -eq $fieldToCheckAccountValue } 


            Write-Information "Queried CSV row where [attributeName] = [$($fieldToCheck.Value.systemFieldName)] AND [attributeValue] = [$($fieldToCheckAccountValue)]. Result count: $(($csvCurrentRows | Measure-Object).Count)"

            # Check property uniqueness
            $actionMessage = "checking if property [$($fieldToCheck.Name)] with value [$($fieldToCheckAccountValue)] is unique"
            if (@($csvCurrentRows).count -gt 0) {
                foreach ($csvCurrentRow in $csvCurrentRows) {
                    if ($csvCurrentRow.employeeId -eq $a.$correlationAttribute) {
                        Write-Information "Person is using property [$($fieldToCheck.Name)] with value [$($fieldToCheckAccountValue)] themselves."
                    }
                    else {
                        if (-NOT [string]::isNullOrEmpty($csvCurrentRow.whenDeleted)) {
                            $whenDeletedDate = [datetime]($csvCurrentRow.whendeleted)
                            $daysDiff = (New-TimeSpan -Start $whenDeletedDate -End (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")).days
                        }
                        else {
                            $daysDiff = 0
                        }

                        if ($daysDiff -lt $eRef.configuration.RetentionPeriod) {
                            Write-Warning "Property [$($fieldToCheck.Name)] with value [$($fieldToCheckAccountValue)] is not unique. It is currently in use by [$($correlationAttribute)]: [$($csvCurrentRow.$correlationAttribute)]. The associated [whenDeleted] timestamp [$($csvCurrentRow.whenDeleted)] is still within the allowed retention period of [$($eRef.configuration.RetentionPeriod) days]."
                            [void]$nonUniqueFields.Add($fieldToCheck.Name)
                            if (@($fieldToCheck.Value.keepInSyncWith).Count -ge 1) {
                                foreach ($fieldToKeepInSyncWith in $fieldToCheck.Value.keepInSyncWith | Where-Object { $_ -in $a.PsObject.Properties.Name }) {
                                    [void]$nonUniqueFields.Add($fieldToKeepInSyncWith)
                                }
                            }
                        
                            # Break out of the loop as we only need to find one non-unique field to stop the process
                            break
                        }
                        else {
                            Write-Warning "Property [$($fieldToCheck.Name)] with value [$($fieldToCheckAccountValue)] is considered unique. Although it was previously used by [$($correlationAttribute)]: [$($csvCurrentRow.$correlationAttribute)], the [whenDeleted] timestamp [$($csvCurrentRow.whenDeleted)] exceeds the allowed retention period of [$($eRef.configuration.RetentionPeriod) days] and the value will be reused."
                        }
                    }
                }
            }
            elseif (@($csvCurrentRows).count -eq 0) {
                Write-Information "Property [$($fieldToCheck.Name)] with value [$($fieldToCheckAccountValue)] is unique."
            }
        }
    }

    # Set Success to true
    $success = $true
}
catch {
    $ex = $PSItem
    
    $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

    # Set Success to false
    $success = $false

    Write-Warning $warningMessage

    # Required to write an error as uniqueness check doesn't show auditlog
    Write-Error $auditMessage
}
finally {
    $nonUniqueFields = @($nonUniqueFields | Sort-Object -Unique)

    # Send results
    $result = [PSCustomObject]@{
        Success         = $success
        NonUniqueFields = $nonUniqueFields
    }
    
    Write-Output ($result | ConvertTo-Json -Depth 10)
}