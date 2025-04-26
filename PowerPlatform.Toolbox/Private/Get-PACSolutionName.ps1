Function Get-PACSolutionName {
	<#
	.SYNOPSIS
		Gets the unique name of a solution in a Power Platform environment.
	.DESCRIPTION
		Given the display name of a solution, gets its unique name.
	.PARAMETER Solution
		The display name of the solution.
	.PARAMETER EnvironmentName
		The display name of the Power Platform environment.
	.EXAMPLE
		Get-PACSolutionName -Solution "My Solution" -EnvironmentName "My Dev"
		Gets the unique name of the "My Solution" solution from the "My Dev" Power Platform environment.
	#>
	[OutputType([string])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
		<#Category#>'PSReviewUnusedParameter',<#CheckId#>'Solution',
		Justification = 'False positive'
	)]
	param(
		[Parameter(Mandatory)]
		[string]$Solution,

		[Parameter(Mandatory)]
		[Alias("Environment","Env","EnvName")]
		[string]$EnvironmentName
	)

	$envId = Get-PACEnvironmentID $EnvironmentName

	(pac solution list -env $envId --json) | ConvertFrom-Json |
		Where-Object {$_.FriendlyName -eq $Solution} |
		Select-Object -ExpandProperty SolutionUniqueName
}
