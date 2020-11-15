$curDir = Get-Location
$fileName = "versions.txt"
$fullFile = "$curDir\$fileName"
$countThreshold = 5
$skipThreshold = 3

Get-Content $fullFile | Measure-Object -Line -outvariable output
$lines = $output.Lines
if ($lines -gt $countThreshold) {
  Write-Host "Purging beginning of file due to file size" -foregroundcolor "cyan"
  $newFile = Get-Content $fullFile | Select-Object -Skip $skipThreshold 
  $newFile | Out-File $fullFile
}


# Append latest version number to the File
$latestVersion = GitVersion /showvariable MajorMinorPatch

Write-Host "Latest Version:  $latestVersion"
$latestVersion >> versions.txt

