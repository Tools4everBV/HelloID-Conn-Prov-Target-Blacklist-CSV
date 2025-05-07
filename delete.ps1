#################################################
# HelloID-Conn-Prov-Target-Blacklist-csv
# Create or update CSV row
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

$attributeNames = $($actionContext.Data | Select-Object * -ExcludeProperty employeeId).PSObject.Properties.Name

try {
    # Verify account reference
    $actionMessage = "verifying account reference"
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw "The account reference could not be found"
    }

    # Import CSV data
    $actionMessage = "importing data from CSV file at path [$($actionContext.Configuration.CsvPath)]"

    # Only load CSV file when it exists
    $csvContent = $null
    if (Test-Path $actionContext.Configuration.CsvPath) {
        $csvContent = Import-Csv -Path $actionContext.Configuration.CsvPath -Delimiter $actionContext.Configuration.Delimiter -Encoding $actionContext.Configuration.Encoding
    }
    else {
        throw "No CSV file found at path [$($actionContext.Configuration.CsvPath)]."
    }

    Write-Information "Imported data from CSV file at path [$($actionContext.Configuration.CsvPath)]. Result count: $(($csvContent | Measure-Object).Count)"

    foreach ($attributeName in $attributeNames) {
        # Check if attribute is in CSV file
        $actionMessage = "querying CSV row where [attributeName] = [$($attributeName)] AND [employeeID] = [$($actionContext.References.Account)]"

        $csvCurrentRows = $null
        $csvCurrentRows = $csvContent | Where-Object { $_.attributeName -eq $attributeName -and $_.employeeID -eq $actionContext.References.Account }

        Write-Information "Queried CSV row where [attributeName] = [$($attributeName)] AND [employeeID] = [$($actionContext.References.Account)]. Result count: $(($csvCurrentRows | Measure-Object).Count)"

        foreach ($csvCurrentRow in $csvCurrentRows) {
            if ([string]::isNullOrEmpty($csvCurrentRow.whenDeleted)) {
                $action = "Update"
            }
            else {
                $action = "WhenDeletedAlreadySet" 
            }
        
            switch ($action) {
                "Update" {
                    # Update CSV row
                    $now = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
                    $actionMessage = "updating [whenDeleted] to [$($now)] for CSV row where [$($attributeName)] = [$($csvCurrentRow.attributeValue)] AND [employeeID] = [$($actionContext.References.Account)]"

                    # Create custom updated CSV object
                    $updatedCsvContent = $null
                    $updatedCsvContent = [System.Collections.ArrayList]@(
                        $csvContent | Where-Object {
                            !(
                                $_.attributeName -eq $csvCurrentRow.attributeName -and
                                $_.attributeValue -eq $csvCurrentRow.attributeValue -and
                                $_.employeeId -eq $csvCurrentRow.employeeId
                            )
                        }
                    )

                    # Add new CSV row to custom updated CSV object
                    $newRowObject = [PSCustomObject]@{
                        attributeName  = $attributeName
                        attributeValue = $csvCurrentRow.attributeValue
                        employeeId     = $actionContext.References.Account
                        whenDeleted    = $now
                        whenUpdated    = $now
                        whenCreated    = $csvCurrentRow.whenCreated
                    }
                    [void]$updatedCsvContent.Add($newRowObject)

                    # Export updated CSV object
                    $exportCsvSplatParams = @{
                        Path              = $actionContext.Configuration.CsvPath
                        Delimiter         = $actionContext.Configuration.Delimiter
                        Encoding          = $actionContext.Configuration.Encoding
                        NoTypeInformation = $true
                        ErrorAction       = "Stop"
                        Verbose           = $false
                    }

                    if (-Not($actionContext.DryRun -eq $true)) {
                        $null = $updatedCsvContent | Foreach-Object { $_ } | Sort-Object -Property employeeId, whenUpdated, whenCreated | Export-Csv @exportCsvSplatParams

                        $outputContext.AuditLogs.Add([PSCustomObject]@{
                                # Action  = "" # Optional
                                Message = "Updated [whenDeleted] to [$($now)] for CSV row where [$($attributeName)] = [$($csvCurrentRow.attributeValue)] AND [employeeID] = [$($actionContext.References.Account)]."
                                IsError = $false
                            })
                        
                        # Reload the CSV content from file to reflect the latest changes
                        $csvContent = Import-Csv -Path $actionContext.Configuration.CsvPath -Delimiter $actionContext.Configuration.Delimiter -Encoding $actionContext.Configuration.Encoding
                    
                        Write-Information "Imported updated data from CSV file at path [$($actionContext.Configuration.CsvPath)]. Result count: $(($csvContent | Measure-Object).Count)"
                    }
                    else {
                        Write-Warning "DryRun: Would update [whenDeleted] to [$($now)] for CSV row where [$($attributeName)] = [$($csvCurrentRow.attributeValue)] AND [employeeID] = [$($actionContext.References.Account)]."
                    }

                    break
                }

                "WhenDeletedAlreadySet" {
                    $actionMessage = "skipping updating CSV row where [$($attributeName)] = [$($csvCurrentRow.attributeValue)] AND [employeeID] = [$($actionContext.References.Account)]"

                    $outputContext.AuditLogs.Add([PSCustomObject]@{
                            # Action  = "" # Optional
                            Message = "Skipped updating CSV row where [$($attributeName)] = [$($csvCurrentRow.attributeValue)] AND [employeeID] = [$($actionContext.References.Account)]. reason: [whenDeleted] is already set."
                            IsError = $false
                        })

                    break
                }
            }
        }

        # Clear updatedCsvContent
        $updatedCsvContent = $null
    }
}
catch {
    $ex = $PSItem

    $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

    Write-Warning $warningMessage

    $outputContext.AuditLogs.Add([PSCustomObject]@{
            # Action  = "" # Optional
            Message = $auditMessage
            IsError = $true
        })
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-NOT($outputContext.AuditLogs.IsError -contains $true)) {
        $outputContext.Success = $true
    }
}