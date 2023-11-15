#####################################################
# HelloID-Conn-Prov-Target-Blacklist-Create-CSV
#
# Version: 1.0.0
#####################################################
# Initialize default values
$c = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$success = $false # Set to false at start, at the end, only when no error occurs it is set to true
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

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
$account = [PSCustomObject]@{
    "SamAccountName"    = $p.Accounts.MicrosoftActiveDirectory.samaccountname # Property Name has to match the DB column name
    "UserPrincipalName" = $p.Accounts.MicrosoftActiveDirectory.userPrincipalName # Property Name has to match the DB column name
    "Mail"              = $p.Accounts.MicrosoftActiveDirectory.mail # Property Name has to match the DB column name
}
#endregion Change mapping here

# Define aRef
$aRef = $account.UserPrincipalName # Use most unique propertie, e.g. SamAccountName or UserPrincipalName

# Define account properties to store in account data
$storeAccountFields = @("SamAccountName", "UserPrincipalName", "Mail")

try {
    # Update CSV
    try {
        if (-not($dryRun -eq $true)) {
            Write-Verbose "Exporting data to CSV [$($csvPath)]. Account object: $($account | ConvertTo-Json)"

            $account | Export-Csv -Path $csvPath -Delimiter $csvDelimiter -Encoding $csvEncoding -NoTypeInformation -Append -Force -Confirm:$false

            $auditLogs.Add([PSCustomObject]@{
                    # Action  = "" # Optional
                    Message = "Successfully exported data to CSV [$($csvPath)]. Account object: $($account | ConvertTo-Json)"
                    IsError = $false;
                });   
        }
        else {
            Write-Warning "DryRun: Would export data to CSV [$($csvPath)]. Account object: $($account | ConvertTo-Json)"
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
                Message = "Error exporting data to CSV [$($csvPath)]. Account object: $($account | ConvertTo-Json). Error Message: $($auditErrorMessage)"
                IsError = $True
            })
    }

    # Define ExportData with account fields and correlation property 
    $exportData = $account.PsObject.Copy() | Select-Object $storeAccountFields
    # Add aRef to exportdata
    $exportData | Add-Member -MemberType NoteProperty -Name "AccountReference" -Value $aRef -Force
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
            Message = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($verboseErrorMessage)"
            IsError = $True
        })
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-NOT($auditLogs.IsError -contains $true)) {
        $success = $true
    }

    # Send results
    $result = [PSCustomObject]@{
        Success          = $success
        AccountReference = $aRef
        AuditLogs        = $auditLogs
        Account          = $account

        # Optionally return data for use in other systems
        ExportData       = $exportData
    }

    Write-Output ($result | ConvertTo-Json -Depth 10)
}