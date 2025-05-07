#################################################
# HelloID-Conn-Prov-Target-Blacklist-csv
# Create or update CSV row
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

$attributeNames = $($actionContext.Data | Select-Object * -ExcludeProperty employeeId, whenDeleted).PSObject.Properties.Name

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
        $actionMessage = "querying CSV row where [$($attributeName)] = [$($actionContext.Data.$attributeName)]"

        $csvCurrentRow = $null
        $csvCurrentRow = $csvContent | Where-Object { $_.attributeName -eq $attributeName -and $_.attributeValue -eq $actionContext.Data.$attributeName }

        Write-Information "Queried CSV row where [$($attributeName)] = [$($actionContext.Data.$attributeName)]. Result count: $(($csvCurrentRow | Measure-Object).Count)"

        # Calulate action
        $actionMessage = "calculating action"

        # If multiple rows are found, filter additionally for employeeId
        if (($csvCurrentRow | Measure-Object).count -gt 1) {
            $csvCurrentRow = $csvCurrentRow | Where-Object { $_.employeeId -eq $actionContext.References.Account }
        
            Write-Information "Multiple CSV rows found where [$($attributeName)] = [$($actionContext.Data.$attributeName)]. Filtered additionally for employeeId. Result count: $(($csvCurrentRow | Measure-Object).Count)"
        }

        if (($csvCurrentRow | Measure-Object).count -eq 0) {
            $action = "Create"
        }
        elseif (($csvCurrentRow | Measure-Object).count -eq 1) {
            if ($csvCurrentRow.employeeId -ne $actionContext.References.Account) {
                if (-NOT [string]::isNullOrEmpty($csvCurrentRow.whenDeleted)) {
                    $whenDeletedDate = [datetime]($csvCurrentRow.whendeleted)
                    $daysDiff = (New-TimeSpan -Start $whenDeletedDate -End (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")).days
                }
                else {
                    $daysDiff = 0
                }

                if ($daysDiff -lt $actionContext.Configuration.RetentionPeriod) {
                    $action = "OtherEmployeeId"
                }
                else {
                    $action = "Create"
                }
            }
            else {
                if ($csvCurrentRow.whenDeleted -ne '') {
                    $action = "Update"
                }
                else {
                    $action = "NoChanges" 
                }
            }
        }
        elseif (($csvCurrentRow | Measure-Object).count -gt 1) {
            $action = "MultipleFound"
        }

        switch ($action) {
            "Create" {
                # Create CSV row
                $actionMessage = "creating CSV row where [$($attributeName)] = [$($actionContext.Data.$attributeName)] AND [employeeID] = [$($actionContext.References.Account)]"

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
                    attributeValue = $actionContext.Data.$attributeName
                    employeeId     = $actionContext.References.Account
                    whenDeleted    = ''
                    whenUpdated    = ''
                    whenCreated    = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
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
                            Message = "Created row in CSV where [$($attributeName)] = [$($actionContext.Data.$attributeName)] AND [employeeID] = [$($actionContext.References.Account)]."
                            IsError = $false
                        })

                    # Reload the CSV content from file to reflect the latest changes
                    $csvContent = Import-Csv -Path $actionContext.Configuration.CsvPath -Delimiter $actionContext.Configuration.Delimiter -Encoding $actionContext.Configuration.Encoding
                
                    Write-Information "Imported updated data from CSV file at path [$($actionContext.Configuration.CsvPath)]. Result count: $(($csvContent | Measure-Object).Count)"
                }
                else {
                    Write-Warning "DryRun: Would create row in CSV [$($exportCsvSplatParams.Path)] where [$($attributeName)] = [$($actionContext.Data.$attributeName)] AND [employeeID] = [$($actionContext.References.Account)]."
                }

                break
            }

            "Update" {
                # Update CSV row
                $actionMessage = "clearing [whenDeleted] for CSV row where [$($attributeName)] = [$($actionContext.Data.$attributeName)] AND [employeeID] = [$($actionContext.References.Account)]"

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
                    attributeValue = $actionContext.Data.$attributeName
                    employeeId     = $actionContext.References.Account
                    whenDeleted    = ''
                    whenUpdated    = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
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
                            Message = "Cleared [whenDeleted] for CSV row where [$($attributeName)] = [$($actionContext.Data.$attributeName)] AND [employeeID] = [$($actionContext.References.Account)]."
                            IsError = $false
                        })

                    # Reload the CSV content from file to reflect the latest changes
                    $csvContent = Import-Csv -Path $actionContext.Configuration.CsvPath -Delimiter $actionContext.Configuration.Delimiter -Encoding $actionContext.Configuration.Encoding
                
                    Write-Information "Imported updated data from CSV file at path [$($actionContext.Configuration.CsvPath)]. Result count: $(($csvContent | Measure-Object).Count)"
                }
                else {
                    Write-Warning "DryRun: Would clear [whenDeleted] for CSV row where [$($attributeName)] = [$($actionContext.Data.$attributeName)] AND [employeeID] = [$($actionContext.References.Account)]."
                }

                break
            }

            "NoChanges" {
                $actionMessage = "skipping updating CSV row where [$($attributeName)] = [$($actionContext.Data.$attributeName)] AND [employeeID] = [$($actionContext.References.Account)]"

                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        # Action  = "" # Optional
                        Message = "Skipped updating CSV row where [$($attributeName)] = [$($actionContext.Data.$attributeName)] AND [employeeID] = [$($actionContext.References.Account)]. reason: No changes."
                        IsError = $false
                    })

                break
            }

            "OtherEmployeeId" {
                $actionMessage = "updating CSV row where [$($attributeName)] = [$($actionContext.Data.$attributeName)]"

                # Throw terminal error
                throw "A CSV row was found where [$($attributeName)] = [$($actionContext.Data.$attributeName)]. However the EmployeeID [$($csvCurrentRow.employeeId)] doesn't match the current person (expected: [$($actionContext.References.Account)]). Additionally, [whenDeleted] = [$($csvCurrentRow.whenDeleted)] is still within the allowed threshold [$($actionContext.Configuration.RetentionPeriod) days]. This should not be possible. Please check the CSV file for inconsistencies."

                break
            }

            "MultipleFound" {
                $actionMessage = "updating CSV row where [$($attributeName)] = [$($actionContext.Data.$attributeName)]"

                # Throw terminal error
                throw "Multiple rows were found in the CSV file where [$($attributeName)] = [$($actionContext.Data.$attributeName)] AND [employeeID] = [$($actionContext.References.Account)]. This should not be possible. Please check the CSV file for inconsistencies."

                break
            }
        }
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