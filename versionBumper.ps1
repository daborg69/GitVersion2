$curDir = Get-Location
$fileName = "versions.txt"
$fullFile = "$curDir\$fileName"
$countThreshold = 15
$skipThreshold = 10
$shouldCommit = $true
$specialCommitMarker = "|^|"


# Get Current Branch Name
$curBranch = (git branch --show-current)
Write-Host "Current Branch:  $curBranch"


# Determine if there are any changes that need to be committed.  If there are the user needs to fix before we can continue
git update-index -q --refresh
$cleanGit = (git diff-index --quiet HEAD --)
Write-Host $cleanGit
if ($cleanGit -ne $true) {
  Write-Host "Error:  There are uncommitted changes in the the current branch: $curBranch.  These must be committed or discarded before this script can continue" -foregroundcolor "Red"
  Return 100
}


# Clean up the Version folder if necessary
Get-Content $fullFile | Measure-Object -Line -outvariable output | Out-Null
$lines = $output.Lines
if ($lines -gt $countThreshold) {
  Write-Host "Purging beginning of file due to file size" -foregroundcolor "cyan"
  $newFile = Get-Content $fullFile | Select-Object -Skip $skipThreshold 
  $newFile | Out-File $fullFile
}


# Append latest version number to the File
$latestVersion = GitVersion /showvariable MajorMinorPatch
$latestSemVer = GitVersion /showvariable SemVer

Write-Host "Latest Version:  $latestVersion"
Write-Host "Latest SemVer:   $latestSemVer"
$latestVersion >> versions.txt



# At this point the only change in the Commit tree should be the versions.txt file.  We will commit it 
# with a custom tag name and then commit a Version Tag
# We will commit everything, create the tag and then push everything upstream.
if ($shouldCommit -eq $true) {
  $tagName = "Ver$latestSemVer"
  $tagDesc = "Deployed Version:  $curBranch  |  $latestSemVer"
  git add .
  git commit -m "$specialCommitMarker Deployed Version $latestSemVer"
  
  git tag -a $tagName -m $tagDesc
  git push --set-upstream origin $curBranch 
  git push --tags origin
}

