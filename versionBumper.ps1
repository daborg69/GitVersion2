Function Add-GitVersionInfo {
	<#
	.Synopsis
		Updates version information from the current branch into Git Commit messages.  During a non Master commit the following will happen:
		 - 
		If the -Master flag is set then a much larger set of functionality is invoked:
		 - A Git Tag commit occurs, which stamps the current version into a tag with a custom tag descriptor
		 - The branch and the tags are all pushed to the origin server.
	#>
	param (
		[switch]$Master
	)



	$curDir = Get-Location
	$fileName = "versions.txt"
	$fullFile = "$curDir\$fileName"
	$countThreshold = 15
	$skipThreshold = 10
	$shouldCommit = $true
	$specialCommitMarker = "|^|"


	# Get Arguments
	$param1=$args[0]


	# Get Current Branch Name
	$curBranch = (git branch --show-current)
	Write-Host "Current Branch:  $curBranch"


	# Determine if there are any changes that need to be committed.  If there are the user needs to fix before we can continue
	git update-index -q --refresh
	git diff-index --quiet HEAD --
	if (!$?) {
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


}