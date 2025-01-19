# created: 1/18/2025

Function New-PACDeployConfig {
<#
    .SYNOPSIS
        Generates a new deployment settings file for a Power Platform solution.
    .DESCRIPTION
        Generates a new deployment settings file for a Power Platform solution, with intended environment variable values and connection IDs for the target environment.
		The source can either be a solution in a Power Platform environment, or a path to the root of a solution's unpacked files.
    .PARAMETER SourceEnvironment
		The Power Platform environment that contains the solution you want to source from. Accepts partial matching.
    .PARAMETER SolutionName
		The display name for the solution.
    .PARAMETER SourceFolderPath
		The root path of the unpacked solution files.
	.PARAMETER SourceZipFilePath
		The path of the solution ZIP file.
    .PARAMETER TargetEnvironment
		The environment that you want the deployment settings file to be designed for.
    .PARAMETER ConnectionOwner
		The userPrincipalName that the intended connections in the target environment are registered under.
    .EXAMPLE
		PS C:\> New-PACDeployConfig -SourceEnvironment "My DEV Env" -SolutionName MySolution -TargetEnvironment "My PROD Env" -OutPath ".\Settings\DeployConfig.json" -ConnectionOwner "my.account@contoso.com"

		Analyzes the "MySolution" solution currently in "My DEV Env" environment, and generates a Power Platform solution deployment settings file intended for the solution's deployment to "My PROD Env". The connection IDs correspond to connections registered for "my.account@contoso.com".
    .EXAMPLE
		PS C:\> New-PACDeployConfig -SourcePath ".\CoreFiles" -TargetEnvironment "My PROD Env" -OutPath ".\Settings\DeployConfig.json" -ConnectionOwner "my.account@contoso.com"

		Same intended output as in Example 1, but the solution source is a local path instead of extracting a solution from a Power Platform environment.
    .EXAMPLE
		PS C:\> New-PACDeployConfig -SourceZipFilePath ".\solution.zip" -TargetEnvironment "My PROD Env" -OutPath ".\Settings\DeployConfig.json" -ConnectionOwner "my.account@contoso.com"

		Same intended output as in Examples 1 & 2, but referencing an unmanaged solution ZIP file.
	.NOTES
		You will need to have permissions to view the intended connections in the target environment.
#>
    [CmdletBinding()]
    [OutputType([Void])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
		<#Category#>'PSUseShouldProcessForStateChangingFunctions',<#CheckId#>'',
		Justification = 'This is just creating a new JSON file'
	)]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
		<#Category#>'PSReviewUnusedParameter',<#CheckId#>'ConnectionOwner',
		Justification = 'False positive from PSScriptAnalyzer'
	)]
    param(
		[Parameter(ParameterSetName='EnvSource')]
		[Alias('SourceEnv')]
		[string]$SourceEnvironment,

		[Parameter(ParameterSetName='EnvSource')]
		[Alias('SolutionName')]
		[string]$SolutionDisplayName,

		[Parameter(ParameterSetName='PathSource')]
		[string]$SourceFolderPath,

		[Parameter(ParameterSetName='ZipSource')]
		[string]$SourceZipFilePath,

		[Parameter(Mandatory)]
		[Alias('TargetEnv')]
		[string]$TargetEnvironment,

		[Parameter(Mandatory)]
		[Alias('OutPath')]
		[string]$OutputPath,

		[Alias('Owner')]
		[string]$ConnectionOwner
	)

    Begin {
        function WV { #streamline Write-Verbose
            Param($prefix,$message)
            $time = Get-Date -f HH:mm:ss
            Write-Verbose "$time [$($prefix.padright(7,' '))] $message"
        }
        WV -prefix BEGIN -message "Starting $($MyInvocation.MyCommand)"

		#TODO: Check for prior authentication, throw if not present

		$tempSourcePath = [System.IO.Path]::GetTempPath() + '~' + [System.IO.Path]::GetRandomFileName().Split('.')[0]
		$tempCoreFilesPath = "$tempSourcePath\CoreFiles"
    } #Begin

    Process {
		WV -p PROCESS -m "Generating temporary source folder"
		New-Item -Path $tempSourcePath -ItemType Directory
		New-Item -Path $tempCoreFilesPath -ItemType Directory

		WV -p PROCESS -m "Populating temporary source folder"
		#TODO: Double-check all branches, make sure we didn't scramble anything
        if ($PSCmdlet.ParameterSetName -eq 'EnvSource') {
			$sourceEnvId = Get-AdminPowerAppEnvironment *$SourceEnvironment* |
				Select-Object -First 1 -ExpandProperty EnvironmentName
			# pac org select --environment "$sourceEnvId"
			$solutionName = pac solution list --json | ConvertFrom-Json |
				Where-Object {$_.FriendlyName -eq $SolutionDisplayName }
			if (!$solutionName) {
				throw "Unable to locate solution in source environment. Ensure you have the correct spelling and try again."
			}
			pac solution export --environment $sourceEnvId --name $solutionName --path "$tempSourcePath\solution.zip"
			pac solution unpack --zipfile "$tempSourcePath\solution.zip" --folder $tempCoreFilesPath --packagetype unmanaged --allowWrite true
			pac solution create-settings --solution-folder $tempCoreFilesPath --settings-file $OutputPath
		} elseif ($PSCmdlet.ParameterSetName -eq 'PathSource') {
			#TODO: Test if this actually hits the right target
			Get-ChildItem -Path $SourceFolderPath -Recurse | ForEach-Object {
				Copy-Item -Destination $tempCoreFilesPath
			}
			pac solution create-settings --solution-folder $SourceFolderPath --settings-file $OutputPath
		} else { #Zip file as source
			pac solution create-settings --solution-zip $SourceZipFilePath -settings-file $OutputPath
			pac solution unpack --zipfile $SourceZipFilePath --folder $tempCoreFilesPath --packagetype unmanaged --allowWrite true
		}
		$settingsContent = Get-Content -Path $OutputPath -Raw | ConvertFrom-Json

		$targetEnvId = Get-AdminPowerAppEnvironment *$TargetEnvironment* |
			Select-Object -First 1 -ExpandProperty EnvironmentName

		WV -p PROCESS -m "Processing custom connectors (if any)"
		[xml]$customizationsFile = Get-Content -Path "$tempCoreFilesPath\Other\customizations.xml"
		$customConnectors = $customizationsFile.ImportExportXml.connectionreferences.connectionreference |
			Where-Object {$_.customconnectorid}
		if ($customConnectors) {
			foreach ($connector in $customConnectors) {
				$CCLogicalName = $connector.connectionreferencelogicalname
				WV -p PROCESS -m "Processing $CCLogicalName"
				#NOTE: Connections for same custom connector keep same root name,
				# just have a different hash on the end
				$connectorDevId = ($connector.connectorid -Split "/")[-1]
				$connectorRootName = (($connectorDevId -Split "-") |
					Select-Object -SkipLast 1) -Join "-"

				WV -p PROCESS -m "Locating connections for $CCLogicalName in target environment"
				$matchingConnections = Get-AdminPowerAppConnection -EnvironmentName $targetEnvId |
					Where-Object {$_.ConnectorName -like $connectorRootName -and
					$_.CreatedBy.userPrincipalName -eq $ConnectionOwner}
				if (!$matchingConnections) {
					Write-Warning "Cannot locate any connections in target environment for $CCLogicalName"
					continue
				}
				$prodConnection = $matchingConnections | Where-Object {
					$_.DisplayName -match $SolutionDisplayName
				}
				if ((!$prodConnection) -or (!$SolutionDisplayName)) {
					$prodConnection = $matchingConnections[0]
					Write-Warning "Cannot guarantee the accuracy of the connectorId for $ccLogicalName. Please
					make sure your connection contains the name of the solution in its display name, then try running this command again."
				}

				$targetConfigItem = $settingsContent.ConnectionReferences |
					Where-Object {$_.LogicalName -eq $CCLogicalName}
				$targetConfigItem.ConnectorId = $targetConfigItem.ConnectorId -Replace $connectorDevId,$prodConnection.ConnectorName
				$targetConfigItem.ConnectionId = $prodConnection.ConnectionName
				Write-Debug "$CCLogicalName set to '$($prodConnection.DisplayName)' connection (ID: $($prodConnection.ConnectionName))"
			}

			WV -p PROCESS -m "Updating Connection Reference IDs"
			$settingsContent.ConnectionReferences |
				Where-Object {!$_.ConnectionId} |
				ForEach-Object {
					$connectorType = $_.ConnectorId.Split("/")[-1]
					Write-Verbose "Processing $connectorType"
					$matchingConnection = Get-AdminPowerAppConnection -EnvironmentName $targetEnvId -ConnectorName $connectorType |
						Where-Object {$_.CreatedBy.userPrincipalName -eq $ConnectionOwner} |
						Select-Object -First 1
					$_.ConnectionId = $matchingConnection.ConnectionName
			}

			WV -p PROCESS -m "Updating environment variable values"
			$settingsContent.EnvironmentVariables | ForEach-Object {
				WV -p PROCESS -m "Setting value for $($_.SchemaName)"
				$newValue = $null
				$envVarFolderPath = "$tempCoreFilesPath\environmentvariabledefinitions\$($_.SchemaName)"
				if ($sourceEnvId -eq $targetEnvId) {
					$currentValuePath = "$envVarFolderPath\environmentvariablevalues.json"
					if (Test-Path $currentValuePath) {
						$currentValue = (Get-Content $currentValuePath -Raw | ConvertFrom-Json
							).environmentvariablevalues.environmentvariablevalue.value
						$newValue = $currentValue
						Write-Debug @"
EnvVar: $($_.SchemaName)
Setting current value: $newValue
"@
					}
				}
				if (!$newValue) {
					$envVarCore = [Xml](Get-Content -Path "$envVarFolderPath\environmentvariabledefinition.xml")
					$newValue = $envVarCore.environmentvariabledefinition.defaultValue
				}

				$_.Value = $newValue
				Write-Debug @"
EnvVar: $($_.SchemaName)
Setting default value: $newValue
"@
			}

			WV -p PROCESS -m "Outputting new DeployConfig file"
			$settingsContent | ConvertTo-Json | Out-File $OutputPath -Force
			Write-Information "DeployConfig file created at: $OutputPath" -InformationAction Continue
		}
    } #Process

    End {
		Remove-Item -Path $tempSourcePath -Force
        WV -p END -m "Ending $($MyInvocation.MyCommand)"
    } #End
}

