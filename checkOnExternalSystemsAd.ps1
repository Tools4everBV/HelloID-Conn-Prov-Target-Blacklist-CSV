#####################################################
# HelloID-Conn-Prov-Target-Blacklist-Check-On-External-Systems-CSV
#
# Version: 1.0.0
#####################################################
# Initialize default values
$p = $person | ConvertFrom-Json
$success = $false # Set to false at start, at the end, only when no error occurs it is set to true
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()
$NonUniqueFields = [System.Collections.Generic.List[PSCustomObject]]::new()

# The entitlementContext contains the configuration
# - configuration: The configuration that is set in the Custom PowerShell configuration
$eRef = $entitlementContext | ConvertFrom-Json
$c = $eRef.configuration

# The account object contains the account mapping that is configured
$a = $account | ConvertFrom-Json

# Set debug logging
switch ($($c.isDebug)) {
    $true { $VerbosePreference = "Continue" }
    $false { $VerbosePreference = "SilentlyContinue" }
}
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# Used to connect to CSV
$csvPath = $c.CsvPath
$csvDelimiter = $c.Delimiter
$csvEncoding = $c.Encoding

#region Change mapping here
$valuesToCheck = [PSCustomObject]@{
    "SamAccountName"                     = [PSCustomObject]@{ # This is the value that is returned to HelloID in NonUniqueFields
        accountValue = $a.samaccountname
        csvColumn    = "SamAccountName"
    }
    "AdditionalFields.UserPrincipalName" = [PSCustomObject]@{ # This is the value that is returned to HelloID in NonUniqueFields
        accountValue = $a.AdditionalFields.userPrincipalName
        csvColumn    = "UserPrincipalName"
    }
    "AdditionalFields.Mail"              = [PSCustomObject]@{ # This is the value that is returned to HelloID in NonUniqueFields
        accountValue = $a.AdditionalFields.mail
        csvColumn    = "Mail"
    }
}

# Raise iteration of all configured fields when one is not unique
$syncIterations = $false
#endregion Change mapping here

try {
    # Query current data in CSV
    try {
        Write-Verbose "Querying data from CSV [$($csvPath)]"

        $csvContent = Import-Csv -Path $csvPath -Delimiter $csvDelimiter -Encoding $csvEncoding

        Write-Verbose "Successfully queried data from CSV [$($csvPath)]. Result Count: $(($csvContent | Measure-Object).Count)"
    }
    catch {
        $ex = $PSItem
        # Set Verbose error message
        $verboseErrorMessage = $ex.Exception.Message
        # Set Audit error message
        $auditErrorMessage = $ex.Exception.Message

        Write-Verbose "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($verboseErrorMessage)"
        $auditLogs.Add([PSCustomObject]@{
                # Action  = "" # Optional
                Message = "Error querying data data from CSV [$($csvPath)]. Error Message: $($auditErrorMessage)"
                IsError = $True
            })

        # Use throw, as auditLogs are not available in check on external system
        throw "Error querying data from CSV [$($csvPath)]. Error Message: $($auditErrorMessage)"
    }

    # Check values against CSV data
    Try {
        foreach ($valueToCheck in $valuesToCheck.PsObject.Properties) {
            if ($valueToCheck.Value.accountValue -in $csvContent."$($valueToCheck.Value.csvColumn)") {
                Write-Warning "$($valueToCheck.Name) value '$($valueToCheck.Value.accountValue)' is NOT unique in CSV column '$($valueToCheck.Value.csvColumn)'"
                [void]$NonUniqueFields.Add("$($valueToCheck.Name)")
            }
            else {
                Write-Verbose "$($valueToCheck.Name) value '$($valueToCheck.Value.accountValue)' is unique in CSV column '$($valueToCheck.Value.csvColumn)'"
            }
        }
    }
    catch {
        $ex = $PSItem
        # Set Verbose error message
        $verboseErrorMessage = $ex.Exception.Message
        # Set Audit error message
        $auditErrorMessage = $ex.Exception.Message

        Write-Verbose "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($verboseErrorMessage)"
        $auditLogs.Add([PSCustomObject]@{
                # Action  = "" # Optional
                Message = "Error checking mapped values against CSV data. Error Message: $($auditErrorMessage)"
                IsError = $True
            })

        # Use throw, as auditLogs are not available in check on external system
        throw "Error checking mapped values against CSV data. Error Message: $($auditErrorMessage)"
    }
}
catch {
    $ex = $PSItem
    # Set Verbose error message
    $verboseErrorMessage = $ex.Exception.Message
    # Set Audit error message
    $auditErrorMessage = $ex.Exception.Message

    Write-Verbose "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($verboseErrorMessage)"
    # Use throw, as auditLogs are not available in check on external system
    throw "Error performing uniqueness check on external systems. Error Message: $($auditErrorMessage)"
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-NOT($auditLogs.IsError -contains $true)) {
        $success = $true
    }

    # When syncIterations is set to true, set NonUniqueFields to all configured fields
    if (($NonUniqueFields | Measure-Object).Count -ge 1 -and $syncIterations -eq $true) {
        $NonUniqueFields = $valuesToCheck.PsObject.Properties.Name
    }

    # Send results
    $result = [PSCustomObject]@{
        Success         = $success

        # Add field name as string when field is not unique
        NonUniqueFields = $NonUniqueFields
    }

    Write-Output ($result | ConvertTo-Json -Depth 10)
}