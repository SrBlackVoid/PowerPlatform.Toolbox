ForEach ($file in (Get-Item .\Build\*.Tasks.ps1)) {
    . $file
}

$script:moduleName = "PowerPlatform.Toolbox"
$script:projectPath = Split-Path ($MyInvocation.MyCommand.Path) -Parent
#$script:repositoryName = #TODO: Fill in repo name
#$script:sourceURL = #TODO: Fill in source URL

task PowerPlatform.Toolbox.Test @(
    'RepoConnect'
    'PreBuild-Tests'
)

task PowerPlatform.Toolbox.Build @(
    'VersionIncrement'
    'CreateOutputDir'
    'CompileModule'
    'AddSourceFiles'
    'PostBuild-Tests'
)

task PowerPlatform.Toolbox.Publish @(
    'PublishModule'
    'Install'
)

task PowerPlatform.Toolbox.Default @(
    'PowerPlatform.Toolbox.Test'
    'PowerPlatform.Toolbox.Build'
    'PowerPlatform.Toolbox.Publish'
)

task Test PowerPlatform.Toolbox.Test
task Build PowerPlatform.Toolbox.Build
task Publish PowerPlatform.Toolbox.Publish
task . PowerPlatform.Toolbox.Default
