<#
DESCRIPTION: This task increments the version number of the module. Prompts the user for the type of version bump (major/minor/patch).
#>

param(
    [ValidateSet('Major','Minor','Patch')]
    [string]$Bump
)

task VersionIncrement {
    $manifestPath = [IO.Path]::Combine($script:projectPath,$script:moduleName,"$script:moduleName.psd1")
    $moduleVersion = (Import-PowerShellDataFile $manifestPath).ModuleVersion.Split('.')

    [int]$major = $moduleVersion[0]
    [int]$minor = $moduleVersion[1]
    [int]$patch = $moduleVersion[2]

    while($true) {
        $Bump = Read-Host "What kind of version bump is this? [A] Major [I] Minor [P] Patch"
        if(@("A","I","P") -contains $Bump.ToUpper()) {
            break
        } else {
            Write-Host "Invalid entry, please try again"
        }
    }

    switch ($Bump.ToUpper()) {
        "A" {
            $major++
            $minor = 0
            $patch = 0
            break
        }
        "I" {
            $minor++
            $patch = 0
            break
        }
        "P" {
            $patch++
            break
        }
        default {}
    }

    $newVersion = [version]"$major.$minor.$patch"
    Write-Verbose "Bumping module version to [$newVersion]"
    Update-ModuleManifest -Path $manifestPath -ModuleVersion $newVersion

    $script:moduleVersion = $newVersion
    $script:manifestPath = $manifestPath
}

<#
DESCRIPTION: This task creates the output directory for the new version of the module being created (in the .\Outputs folder).
This directory will contain the finished result that is being published to the repository.
#>

task CreateOutputDir {
    #Create output directory
    $outputDir = [IO.Path]::Combine($script:projectPath,'Output')
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null

    $versionOutputDir = [IO.Path]::Combine($outputDir,$script:moduleVersion,$script:moduleName)

    if (Test-Path -Path $versionOutputDir) {
        #Make sure the directory is empty if it already exists
        Get-ChildItem -Path $versionOutputDir -Recurse | Remove-Item -Force
    } else {
        #Create version directory in output directory
        New-Item -Path $versionOutputDir -ItemType Directory | Out-Null
    }

    $script:versionOutputDir = $versionOutputDir
}


<#
DESCRIPTION: This task takes all of the .ps1 files that are embedded within the source folder, and appends them all together into a single .psm1 module file to be published.
The idea behind this is during development, it's easier to work with separate file concerns, but in performance it's faster to load everything from a single module file.

The module also copies the module manifest from the Source folder into the outputs, and updates that manifest to list the intended Public functions.
This allows you to include Private functions as well in your build, but not have them visible to users.
#>

task CompileModule {
    #Concatenate all source files into root PSM1
    $rootModule = [IO.Path]::Combine($script:versionOutputDir,"$script:moduleName.psm1")
    $rootPath = "$script:projectPath/$script:moduleName"
    $script:foldersToCompile = @(
        "Private"
        "Public"
    )

    ForEach ($folder in $foldersToCompile) {
        $sourceFiles = Get-ChildItem "$rootPath/$folder" -Filter '*.ps1' -Recurse

        $sourceFiles | ForEach-Object {
            "# source: $($_.Name)"
            $_ | Get-Content
            ''
        } | Add-Content -Path $rootModule -Encoding utf8
    }

    #Copy module manifest
    $outputManifest = Copy-Item -Path $script:manifestPath -Destination $script:versionOutputDir -PassThru

    #Update FunctionsToExport
    $publicFunctions = Get-ChildItem -Path ./$script:moduleName/Public -Filter '*.ps1' -Recurse
    $updateManifestParams = @{
        Path = $outputManifest
        FunctionsToExport = $publicFunctions.BaseName
        CmdletsToExport = $publicFunctions.BaseName    
    }
    Update-ModuleManifest @updateManifestParams
}

<#DESCRIPTION: This task locates all aliases set on your public functions and includes them in the manifest to be published.#>
task ExportAliases {
	$functionDefinitions = foreach ($File in Get-ChildItem -Path ".\$script:moduleName\Public" -Filter "*.ps1" -File) {
		$Tokens = $null
		$Errors = $null
		$BaseAst = [System.Management.Automation.Language.Parser]::ParseFile($File.FullName, [ref]$Tokens, [ref]$Errors)
		$BaseAst.FindAll({
			param ($Ast)
			$Ast -is [System.Management.Automation.Language.FunctionDefinitionAst]
		},$true)
	}

	$functionAliasNames = ($FunctionDefinitions.Body.ParamBlock.Attributes |
		Where-Object {$_.TypeName.Name -eq "Alias"}
	).PositionalArguments.Value | Sort-Object

	if ($functionAliasNames) {
		Update-ModuleManifest -Path $script:outputManifest -AliasesToExport $functionAliasNames
	}
}

<#DESCRIPTION: This task adds any non-compiled files that are intended to be included in the module package.#>
task AddSourceFiles {
    $addFolderParams = @{
        Path = "$script:projectPath/$script:moduleName"
        Directory = $true
        Exclude = $script:foldersToCompile
    }
    $foldersToAdd = Get-ChildItem @addFolderParams

    ForEach ($folder in $foldersToAdd) {
        Copy-Item -Path $folder.FullName -Destination $script:versionOutputDir -Recurse
    }
}

<#DESCRIPTION: This task runs any "Build"-tagged tests that are intended to verify the results of the compiled module.#>
task PostBuild-Tests {
	$testFiles = Get-ChildItem -Path .\Test\ -Filter "*.Tests.ps1" -Recurse
	$containerParams = @{
        Path = $testFiles.FullName
		Data = @{
			modulePath = $script:versionOutputDir
		}
	}
	$testContainer = New-PesterContainer @containerParams
	
    $buildTestConfig = New-PesterConfiguration -Hashtable @{
        Filter = @{
            Tag = "Build"
        }
        Output = @{
            Verbosity = "Detailed"
        }
        Run = @{
            Exit = $true
			Container = $testContainer
        }
    }
    Invoke-Pester -Configuration $buildTestConfig
}

