function Update-CustomConnector {
	<#
	.SYNOPSIS
		Updates a custom connector in a Power Platform environment.
	.DESCRIPTION
		Updates a custom connector in a Power Platform environment with the definitions supplied in the folder path specified.
	.PARAMETER SourcePath
		The root folder path containing the custom connector definition files.
	.PARAMETER EnvironmentName
		The display name of the target Power Platform environment.
	.EXAMPLE
		PS C:\> Update-CustomConnector -Path .\CustomConnectors\MyConnector -EnvironmentName "My Prod"

		Updates the custom connector associated with the definition found in .\CustomConnectors\MyConnector in the "My Prod" environment.
	#>


	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory)]
		[string]$SourcePath,

		[Parameter(Mandatory)]
		[Alias("Environment","Env","EnvName")]
		[string]$EnvironmentName
	)

	begin {
		Write-Verbose "Starting $($MyInvocation.MyCommand)"

		$apiDefFile = "$SourcePath\apiDefinition.json"
		$apiPropertiesFile = "$SourcePath\apiProperties.json"
		$iconFile = "$SourcePath\icon.png"
		$scriptFile = "$SourcePath\script.csx"

		$pacCall = "pac connector update "

		$envId = Get-PACEnvironmentID $EnvironmentName
		$connectorName = (Get-Content -Path $apiDefFile -Raw |
			ConvertFrom-Json -Depth 10
		).info.title
	}

	process {
		Write-Verbose "Compiling PAC CLI command"
		$connectorId = Get-PACConnectorId -Connector $connectorName -EnvironmentName $EnvironmentName
		if (!$connectorId) {
			throw "Unable to locate the connector in the target environment. Ensure you have the correct connector definition and environment name and try again."
		}

		$pacCall += "-id $connectorId -env $envId "
		$pacCall += "-df '$apiDefFile' -pf '$apiPropertiesFile'"

		if (Test-Path $iconFile) {
			$pacCall += " -if '$iconFile'"
		}

		if (Test-Path $scriptFile) {
			$pacCall += " -sf '$scriptFile'"
		}

		if ($Solution -and !($Update)) {
			$solutionName = Get-PACSolutionName -Solution $Solution -EnvironmentName $EnvironmentName
			$pacCall += " -sol $SolutionName"
		}

		Write-Verbose "Executing command"
		Write-Debug "full command: $pacCall"
		if ($PSCmdlet.ShouldProcess($EnvironmentName,"Updating $connectorName")) {
			$pacScript = [scriptblock]::Create($pacCall)
			Invoke-Command $pacScript
		}
	}

	end {
		Write-Verbose "Ending $($MyInvocation.MyCommand)"
	}
}
