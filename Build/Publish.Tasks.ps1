<#
DESCRIPTION: This task publishes the module build in the newest version dir in .\Outputs to the repository.
#>

task PublishModule {
    $moduleBuild = @{
        Path = $script:versionOutputDir
        Repository = $script:repositoryName
        #NuGetApiKey = "key"
    }
    Write-Host "Publishing $script:moduleName to $script:repositoryName"

    Publish-Module @moduleBuild
}


<#
DESCRIPTION: This task installs the module (or updates it if it's not already installed).
#>

task Install {
    Write-Host "Installing $script:moduleName"
    if (Get-Module -Name $script:moduleName -ListAvailable) {
        Update-Module -Name $script:moduleName -Scope AllUsers
    } else {
        Install-Module -Name $script:moduleName -Scope AllUsers -Repository $script:repositoryName
    }
}
