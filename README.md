# HelloID-Conn-Prov-Target-Blacklist-CSV

> [!IMPORTANT]  
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://raw.githubusercontent.com/Tools4everBV/HelloID-Conn-Prov-Target-Blacklist-CSV/refs/heads/v2/Logo.png">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-Blacklist-CSV](#helloid-conn-prov-target-blacklist-csv)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Connection settings](#connection-settings)
    - [Available Lifecycle Actions](#available-lifecycle-actions)
    - [CSV structure](#csv-structure)
  - [Remarks](#remarks)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-Blacklist-CSV_ is a target connector that writes user attribute values to a CSV-based blacklist. These values can later be used to prevent reuse, for example of `sAMAccountName`, `email`, or `UPN`.

## Getting started

### Prerequisites

- HelloID Agent running On-Premises
- Write access to a shared location for storing the blacklist CSV file

### Connection settings

The following settings are required to connect to the CSV file.

| Setting                | Description                                                                                                                               | Mandatory |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| CSV File Path          | Full path to the CSV file                                                                                                                 | Yes       |
| Delimiter              | Delimiter used in the file (e.g. `,`)                                                                                                     | Yes       |
| Encoding               | Encoding used (e.g. `utf-8`, `ascii`)                                                                                                     | Yes       |
| RetentionPeriod (days) | Retention period in days. This is the number of days the value should remain blocked after deletion. Use `999999` for no retention limit. | Yes       |

### Available Lifecycle Actions

The following lifecycle actions are available in this connector:

| Action                         | Description                                                                                                                                                                                                                                                                                                                                                                                                 | Comment                                                                                                   |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `create.ps1`                   | Adds account data to the blacklist CSV. A new row is added if the combination of attribute + employeeId doesn't exist, or if the attribute belongs to someone else but is outside the retention period. If the entry exists and is soft-deleted (i.e., `whenDeleted` is set), but the same person owns it and it's within the retention period, the `whenDeleted` field is cleared to reactivate the entry. | Uses account data from another system like AD or Entra ID.                                                |
| `update.ps1`                   | Follows the same logic as `create.ps1`. The row is either added or restored based on ownership and retention policy.                                                                                                                                                                                                                                                                                        |                                                                                                           |
| `delete.ps1`                   | Marks the value as soft-deleted by filling the `whenDeleted` field for any rows where it's still empty.                                                                                                                                                                                                                                                                                                     |                                                                                                           |
| `checkOnExternalSystemsAd.ps1` | Verifies if attribute values exist in the blacklist. It checks the `whenDeleted` field to ensure the value is still within the retention period and determines if it should remain blocked.                                                                                                                                                                                                                 | Configured in the built-in AD connector.                                                                  |
| `configuration.json`           | Contains connection settings and general configuration for the connector.                                                                                                                                                                                                                                                                                                                                   | This configuration can and should be used in both the CSV target connector and the built-in AD connector. |
| `fieldMapping.json`            | Defines mappings between person fields and target system person account fields.                                                                                                                                                                                                                                                                                                                             |                                                                                                           |


### CSV structure

| Column           | Description                                                                                                                                    |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `employeeId`     | Unique ID from source system (usually HR)                                                                                                      |
| `attributeName`  | The attribute name (e.g. `userPrincipalName`, `sAMAccountName`, or `mail`)                                                                     |
| `attributeValue` | The attribute value to block                                                                                                                   |
| `whenCreated`    | Timestamp when the row was created                                                                                                             |
| `whenDeleted`    | Soft-delete; if set, the row will still be validated, but only considered a match if within the retention period defined by `RetentionPeriod`. |

## Remarks

- This connector uses a local CSV file as storage and source of truth.
- The columns `whenCreated`, `whenUpdated`, and `whenDeleted` are fixed in the code.
  > These fields are **not available in fieldMapping** by design.
- Multiple rows per attribute and per employee are supported.

## Getting help

> [!TIP]  
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

> [!TIP]  
> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
