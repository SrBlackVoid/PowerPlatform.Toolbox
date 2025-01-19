<#
	DESCRIPTION: This build task tests the connection to the specified repository.
#>

task RepoConnect {
    <# try{
		Get-PackageSource -name $script:repositoryName -ProviderName "NuGet" -ErrorAction stop | out-null
	}
	catch{
		$packagesource = @{
			Name = $script:repositoryName
			Location = $script:sourceURL
			ProviderName = "NuGet"
			SkipValidate = $true
		}
		Register-PackageSource @packagesource
	} #>

	try{
		Get-PSRepository -name $script:repositoryName -ErrorAction stop | out-null
	}
	catch{
		$repo = @{
			Name = $script:repositoryName
			SourceLocation = $script:sourceURL
			PublishLocation = $script:sourceURL
			InstallationPolicy = "Trusted"
		}
		Register-PsRepository @repo
	}
}

<#
DESCRIPTION: This test runs any Pester tests that are in the current opened folder tree.
#>

task PreBuild-Tests {
	$testFiles = Get-ChildItem -Path .\Test\ -Filter "*.Tests.ps1" -Recurse
	$sourceFiles = Get-ChildItem -Path .\$script:moduleName -Directory |
		ForEach-Object {
			Get-ChildItem -Path $_.FullName -Filter "*.ps1" -Recurse
		}
	$containerParams = @{
		Path = $testFiles.FullName
		Data = @{
			modulePath = "$script:projectPath\$script:moduleName\$script:moduleName.psm1"
		}
	}
	$testContainer = New-PesterContainer @containerParams
	
    $buildTestConfig = New-PesterConfiguration -Hashtable @{
        Filter = @{
            Tag = "Test"
        }
        Output = @{
            Verbosity = "Detailed"
        }
        Run = @{
            Exit = $true
			Container = $testContainer
        }
		<# CodeCoverage = @{
			Enabled = $true
			Path = $sourceFiles.FullName
		} #>
    }
    Invoke-Pester -Configuration $buildTestConfig
}

