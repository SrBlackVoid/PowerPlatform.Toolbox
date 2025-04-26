function Deploy-CustomConnector {
	<#
	.SYNOPSIS
		Deploys a custom connector in a Power Platform environment.
	.DESCRIPTION
		Deploys a new custom connector to a Power Platform environment. For updating its definition in the environment, use Update-CustomConnector.
	.PARAMETER SourcePath
		The root folder path containing the custom connector definition files.
	.PARAMETER EnvironmentName
		The display name of the target Power Platform environment.
	.PARAMETER Solution
		If you wish to add the custom connector to an unmanaged solution in the environment, enter the solution display name here.
	.EXAMPLE
		PS C:\> Deploy-CustomConnector -Path .\CustomConnectors\MyConnector -EnvironmentName "My Prod"

		Deploys the custom connector defined in .\CustomConnectors\MyConnector to the "My Prod" environment.
	.EXAMPLE
		PS C:\> Deploy-CustomConnector -Path .\CustomConnectors\MyConnector -EnvironmentName "My Prod" -Solution "My Connector Repo"

		Deploys the custom connector defined in .\CustomConnectors\MyConnector to the "My Prod" environment. Adds the connector to the "My Connector Repo" solution.
	#>


	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory)]
		[string]$SourcePath,

		[Parameter(Mandatory)]
		[Alias("Environment","Env","EnvName")]
		[string]$EnvironmentName,

		[string]$Solution
	)

	begin {
		Write-Verbose "Starting $($MyInvocation.MyCommand)"

		$apiDefFile = "$SourcePath\apiDefinition.json"
		$apiPropertiesFile = "$SourcePath\apiProperties.json"
		$iconFile = "$SourcePath\icon.png"
		$scriptFile = "$SourcePath\script.csx"

		$pacCall = "pac connector create "

		$envId = Get-PACEnvironmentID $EnvironmentName
	}

	process {
		Write-Verbose "Compiling PAC CLI command"
		$pacCall += "-env $envId "
		$pacCall += "-df '$apiDefFile' -pf '$apiPropertiesFile'"

		if (Test-Path $iconFile) {
			$pacCall += " -if '$iconFile'"
		}

		if (Test-Path $scriptFile) {
			$pacCall += " -sf '$scriptFile'"
		}

		if ($Solution) {
			$solutionName = Get-PACSolutionName -Solution $Solution -EnvironmentName $EnvironmentName
			$pacCall += " -sol $SolutionName"
		}

		Write-Verbose "Executing command"
		Write-Debug "full command: $pacCall"
		if ($PSCmdlet.ShouldProcess($SourcePath)) {
			$pacScript = [scriptblock]::Create($pacCall)
			Invoke-Command $pacScript
		}
	}

	end {
		Write-Verbose "Ending $($MyInvocation.MyCommand)"
	}
}
