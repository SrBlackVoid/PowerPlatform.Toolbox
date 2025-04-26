function Get-CustomConnectorDefinition {
	<#
	.SYNOPSIS
		Downloads the definition files for a custom connector in a Power Platform environment.
	.DESCRIPTION
		Downloads the definition files for a custom connector in a Power Platform environment.
	.PARAMETER ConnectorName
		The name of the custom connector.
	.PARAMETER EnvironmentName
		The display name of the Power Platform environment that the custrom connector is located.
	.PARAMETER OutputPath
		The folder path to download the connector's definition files to.
	.EXAMPLE
		PS C:\> Get-CustomConnectorDefinition -ConnectorName "My Connector" -EnvironmentName "My Dev" -OutputPath ".\CustomConnectors\My Connector"

		Downloads the definition files for the "My Connector" custom connector from the "My Dev" environment, and saves them to ".\CustomConnectors\My Connector".
	#>

	[CmdletBinding(SupportsShouldProcess)]
	[OutputType([Void])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
		<#Category#>'PSReviewUnusedParameter',<#CheckId#>'ConnectorName',
		Justification = 'False positive'
	)]
	param (
		[Parameter(Mandatory)]
		[string]$ConnectorName,

		[Parameter(Mandatory)]
		[string]$EnvironmentName,

		[Parameter(Mandatory)]
		[string]$OutputPath
	)

	$envId = Get-PACEnvironmentID $EnvironmentName

	$connectors = (pac connector list -env $envId --json) | ConvertFrom-Json
	$connectorId = ($connectors | Where-Object {
		$_.DisplayName -eq $ConnectorName
	}).ConnectorId
	if (!$connectorId) {
		throw "Unable to locate connector in target environment. Check the spelling and try again."
	}

	Write-Verbose "Downloading custom connector definition files"
	if ($PSCmdlet.ShouldProcess($EnvironmentName,"pac connector download")) {
		pac connector download --connector-id $connectorId --outputDirectory $OutputPath --environment $envId
	}
}
