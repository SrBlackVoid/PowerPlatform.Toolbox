[cmdletbinding()]
param()

Write-Verbose 'Import all PS1 files in source folders'
$foldersToExclude = @("Classes") #Add folders containing non-ps1 files
$folderImportParams = @{
    Path = $PSScriptRoot
    Directory = $true
    Exclude = $foldersToExclude
}

$foldersToImport = (Get-ChildItem @folderImportParams).BaseName
foreach($folder in $foldersToImport) {
    $root = Join-Path -Path $PSScriptRoot -ChildPath $folder
    if(Test-Path -Path $root){
        Write-Verbose "processing folder $root"
        $files = Get-ChildItem -Path $root -Filter *.ps1 -Recurse

        # dot source each file
        $files | where-Object{ $_.name -NotLike '*.Tests.ps1'} | 
            ForEach-Object{Write-Verbose $_.basename; . $_.FullName}
    }
}
