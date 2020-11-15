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


	# Global Variables
	$curDir = Get-Location
	$fileName = "versions.txt"
	$fullFile = "$curDir\$fileName"
	$countThreshold = 15
	$skipThreshold = 10
	$shouldCommit = $true
	$specialCommitMarker = "|^|"
	$curBranch = ""


	######################
	#  Gets the current Git branch
	######################
	Function GetCurrentBranch {
		# Get Current Branch Name
		$branch = (git branch --show-current)
		Write-Host "Current Branch:  $branch" -foregroundcolor "Green"
		$branch
	}


	######################
	#  Process the Versions File.  Purging old entries if needed and adding new Version info if it does not match latest entry.
	#  Returns a Variable with LatestVersion and LatestSemVer properties.
	######################
	Function ProcessVersionsFile {
		Get-Content $fullFile | Measure-Object -Line -outvariable output | Out-Null
		$lines = $output.Lines
		if ($lines -gt $countThreshold) {
		  Write-Host "Purging beginning of file due to file size" -foregroundcolor "cyan"
		  $newFile = Get-Content $fullFile | Select-Object -Skip $skipThreshold 
		  $newFile | Out-File $fullFile
		}


		# Read latest version from file
		$previousVersion = Get-Content $fullFile -Tail 1 
		Write-Host "Previous Version Committed:  $previousVersion"


		# Append latest version number to the File
		$latestVersion = GitVersion /showvariable MajorMinorPatch
		$latestSemVer = GitVersion /showvariable SemVer

		$rc = [PSCustomObject]@{
			LatestVersion = $latestVersion
			LatestSemVer = $latestSemVer
		}

		# Write NewVersion to file if not the same as prio
		$newVersion = "$latestVersion|$latestSemVer"
		if ($newVersion -ne $previousVersion) {
			$newVersion >> versions.txt
		}

		return $rc
	}

	 
	# Get Current Branch
	$curBranch = GetCurrentBranch


	# Determine if there are any changes that need to be committed.  If there are the user needs to fix before we can continue
	git update-index -q --refresh
	git diff-index --quiet HEAD --
	if (!$?) {
		Write-Host ""
		Write-Host "Error:  There are uncommitted changes in the the current branch: $curBranch.  These must be committed or discarded before this script can continue" -foregroundcolor "Red"
		Return 100
	}



	########################
	###### Script Start
	########################
	Write-Host ""
	Write-Host ""
	Write-Host ""
	# Update the Versions folder with latest.
	$versions = ProcessVersionsFile;
	Write-Host "Last Versions:  $($versions.LatestVersion)  ---0----- $($versions.LatestSemVer)"
	Write-Host
	Write-Host

	# At this point the only change in the Commit tree should be the versions.txt file.  We will commit it 
	# with a custom tag name and then commit a Version Tag
	# We will commit everything, create the tag and then push everything upstream.
	if ($shouldCommit -eq $true) {
		$tagName = "Ver$($versions.LatestSemVer)"
		$tagDesc = "Deployed Version:  $curBranch  |  $($versions.LatestSemVer)"
		git add .
		git commit -m "$specialCommitMarker $tagDesc"
  
		git tag -a $tagName -m $tagDesc
		git push --set-upstream origin $curBranch 
		git push --tags origin
	}

	if (!$?) { 
		Write-Host ""
		Write-Host "ERROR:  Problems adding Version Commit and Tag."
		Return 101
	}

	
		# Closing

		Write-Host "Latest Version:  $latestVersion"
		Write-Host "Latest SemVer:   $latestSemVer"
		Write-Host "Git Tagged:      $tagDesc"
	
}

Add-GitVersionInfo