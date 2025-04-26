param(
    [Parameter(Mandatory)]
    $modulePath,
    $FoldersToExcludeForScriptAnalysis
)

BeforeDiscovery {
    $sourceFiles = Get-ChildItem (Split-Path $modulePath -Parent) -Directory -Exclude $FoldersToExcludeForScriptAnalysis | ForEach-Object {
        Get-ChildItem -Path $_.FullName -Filter *.ps1 -Recurse | ForEach-Object {
            @{
                Name = $_.BaseName
                Path = $_.FullName
            }
        }
    }
}

Describe 'Module Manifest Tests' -Tag "Test","Build" {
    BeforeAll {
        $ModuleName = 'PowerPlatform.Toolbox'
        if($modulePath -match ".psm1") {
            $manifestPath = "$(Split-Path $modulePath -Parent)\$moduleName.psd1"
        } else {
            $manifestPath = "$modulePath\$moduleName.psd1"
        }
    }
    It 'Passes Test-ModuleManifest' {
        Test-ModuleManifest -Path $manifestPath | Should -Not -BeNullOrEmpty
        $? | Should -Be $true
    }
}

Describe 'Script Analysis' -Tag "Test" {
	It "<Name>" -ForEach $sourceFiles {
		$checker = Invoke-ScriptAnalyzer -Path $Path
		$checker | Should -BeNullOrEmpty
	}
}
