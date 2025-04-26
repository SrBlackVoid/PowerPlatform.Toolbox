# PowerPlatform.Toolbox

This module contains some helpful commands that I have used on a regular basis to drastically speed up processes related to ALM in Power Platform.

## Commands

### New-PACDeployConfig

For those of you who are using either PAC CLI or Power Platform Build Tools to handle solution imports, this command analyzes your solution and generates a new deployment settings file, filling in environment variable values and connection IDs specific to your target environment. You can reference either a solution in a Power Platform environment, a solution ZIP file, or the root path of a solution's unpacked files.

#### Notes and Limitations

- For environment variable values, it will use the default values from your solution _unless_ you specified the same environment for your source and target, in which case it will reference current values (if set).
- It can only handle one specified account for the connections. If your solution utilizes connections from multiple accounts, you will need to complete the rest on your own (or run it again with the other accounts and do some merging).
- It _can_ handle custom connectors across environments, provided the custom connector was exported/imported via solution to the target environment (this retains the same root ID between environments)
  - I also add a general practice of setting the connection's display name to contain the solution name somewhere in it (so I know what uses it and what auth is associated with it), so this function looks for that in the target environment. If that is **not** the case, it will select the first match it finds (but will warn you).

### Get-CustomConnectorDefinition

This command simplifies the process of downloading the definition files for a custom connector from a selected environment. Pretty straightforward.

## Requirements

- Power Platform CLI v. 1.34 or higher (https://learn.microsoft.com/en-us/power-platform/developer/cli/introduction)
- Microsoft.PowerApps.Administration.PowerShell module
- Only compatible with PowerShell 5.1 due to current internal conflicts with .NET Core (https://learn.microsoft.com/en-us/power-platform/admin/powerapps-powershell#prerequisites)
