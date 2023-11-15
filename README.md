# HelloID-Conn-Prov-Target-Blacklist-CSV
Repository for HelloID Provisioning Target Connector to CSV Blacklist

<a href="https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Blacklist-CSV/network/members"><img src="https://img.shields.io/github/forks/Tools4everBV/HelloID-Conn-Prov-Target-Blacklist-CSV" alt="Forks Badge"/></a>
<a href="https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Blacklist-CSV/pulls"><img src="https://img.shields.io/github/issues-pr/Tools4everBV/HelloID-Conn-Prov-Target-Blacklist-CSV" alt="Pull Requests Badge"/></a>
<a href="https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Blacklist-CSV/issues"><img src="https://img.shields.io/github/issues/Tools4everBV/HelloID-Conn-Prov-Target-Blacklist-CSV" alt="Issues Badge"/></a>
<a href="https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Blacklist-CSV/graphs/contributors"><img alt="GitHub contributors" src="https://img.shields.io/github/contributors/Tools4everBV/HelloID-Conn-Prov-Target-Blacklist-CSV?color=2b9348"></a>

| :information_source: Information |
| :------------------------------- |
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.  |

<p align="center">
  <img src="https://cdn-icons-png.flaticon.com/128/4443/4443857.png">
</p>

## Table of Contents
- [HelloID-Conn-Prov-Target-Blacklist-CSV](#helloid-conn-prov-target-blacklist-csv)
  - [Table of Contents](#table-of-contents)
  - [Requirements](#requirements)
  - [Introduction](#introduction)
    - [Connection settings](#connection-settings)
  - [Remarks](#remarks)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Requirements
- Required to run **On-Premises**
- CSV file

## Introduction
With this connector we have the option to write unique values, e.g. SamAccountName and/or UserPrincipalName to a blacklist CSV file.

The HelloID connector consists of the template scripts shown in the following table.

| Action                     | Action(s) Performed             | Comment                                                   |
| -------------------------- | ------------------------------- | --------------------------------------------------------- |
| create.ps1                 | Write account data to CSV       | Uses account data from another system like AD or Azure AD |
| checkOnExternalSystems.ps1 | Check mapped fields against CSV | This is configured in the built-in AD connector           |

### Connection settings
The following settings are required to connect to CSV.

| Setting       | Description                                   | Mandatory |
| ------------- | --------------------------------------------- | --------- |
| CSV File Path | String value of the path of the CSV file      | Yes       |
| Delimiter     | String value of the delimiter of the CSV file | Yes       |
| Encoding      | String value of the encoding of the CSV file  | Yes       |

## Remarks
- This connector is designed to connect to an a CSV file that is located on-premises. Optionally you can also configure this to use cloud storage. However, the connector currently isn't desgined for this and needs additional configuration.

## Getting help
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-Configure-a-custom-PowerShell-target-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs
The official HelloID documentation can be found at: https://docs.helloid.com/