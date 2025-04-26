Function Get-PACEnvironmentID {
	<#
	.SYNOPSIS
		Gets a Power Platform environment's ID from display name.
	.DESCRIPTION
		Uses the display name of a Power Platform environment to get the environment's ID.
	.PARAMETER EnvironmentName
		The display name of the Power Platform environment.
	.EXAMPLE
		PS C:\> Get-PACEnvironmentID -EnvironmentName "My Dev"

		Gets the ID of the "My Dev" Power Platform environment.
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param(
		[Parameter(Mandatory)]
		[Alias("Environment","Env","EnvName")]
		[string]$EnvironmentName
	)

	Get-AdminPowerAppEnvironment *$EnvironmentName* |
		Select-Object -First 1 -ExpandProperty EnvironmentName
}
