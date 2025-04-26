Function Get-PACConnectorId {
	<#
	.SYNOPSIS
		Gets the GUID of a custom connector in a Power Platform environment.
	.DESCRIPTION
		Gets the GUID of a custom connector in a Power Platform environment.
	.PARAMETER Connector
		The display name of the custom connector.
	.PARAMETER EnvironmentName
		The display name of the Power Platform environment where the custom connector is located.
	.EXAMPLE
		Test-MyTestFunction -Verbose
		Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
	#>
	[CmdletBinding()]
	[OutputType([string])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
		<#Category#>'PSReviewUnusedParameter',<#CheckId#>'Connector',
		Justification = 'False positive'
	)]
	param (
	    [Parameter(Mandatory)]
	    [string]$Connector,

		[Parameter(Mandatory)]
		[Alias("Environment","Env","EnvName")]
		[string]$EnvironmentName
	)

	$envId = Get-PACEnvironmentID $EnvironmentName

	(((pac connector list -env $envId --json) | ConvertFrom-Json) |
		Where-Object { $_.DisplayName -eq $Connector}
	).ConnectorId
}
