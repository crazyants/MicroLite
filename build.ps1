param(
  [string]$version,
  [bool]$push
)

$projectName = "MicroLite"

$scriptPath = Split-Path $MyInvocation.InvocationName
$buildDir = "$scriptPath\build"
$nuGetExe = "$scriptPath\tools\NuGet.exe"
$nuSpec = "$scriptPath\$projectName.nuspec"
$nuGetPackage = "$buildDir\$projectName.$version.nupkg"

function UpdateAssemblyInfoFiles ([string] $buildVersion, [string] $commit)
{
	$assemblyVersionPattern = 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
	$fileVersionPattern = 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
	$infoVersionPattern = 'AssemblyInformationalVersion\("[0-9]+(\.([0-9]+|\*)){1,3}(.*)"\)'
	$assemblyVersion = 'AssemblyVersion("' + $buildVersion.SubString(0, 3) + '.0.0")';
	$fileVersion = 'AssemblyFileVersion("' + $buildVersion.SubString(0, 5) + '.0")';
	$infoVersion = 'AssemblyInformationalVersion("' + $buildVersion.SubString(0, 5) + '.' + $commit + '")';
	
	Get-ChildItem $scriptPath -r -filter AssemblyInfo.cs | ForEach-Object {
		$filename = $_.Directory.ToString() + '\' + $_.Name
		$filename + ' -> ' + $buildVersion
			
		(Get-Content $filename) | ForEach-Object {
			% {$_ -replace $assemblyVersionPattern, $assemblyVersion } |
			% {$_ -replace $fileVersionPattern, $fileVersion } |
			% {$_ -replace $infoVersionPattern, $infoVersion }
		} | Set-Content $filename -Encoding UTF8
	}
}

if ($version)
{
	$gitDir = $scriptPath + "\.git"
	$commit = git --git-dir $gitDir rev-list HEAD --count

	UpdateAssemblyInfoFiles -buildVersion $version -commit $commit
}

# Run the psake build script to create the release binaries
Import-Module (Join-Path $scriptPath packages\psake.4.6.0\tools\psake.psm1) -ErrorAction SilentlyContinue

Invoke-psake (Join-Path $scriptPath default.ps1)

Remove-Module psake -ErrorAction SilentlyContinue

if ($version)
{
	Write-Host "Pack $nuSpec -> $nuGetPackage" -ForegroundColor Green
	& $nuGetExe Pack $nuSpec -Version $version -OutputDirectory $buildDir -BasePath $buildDir

	if($push)
	{
		Write-Host "Push $nuGetPackage -> http://nuget.org" -ForegroundColor Green
		& $nuGetExe Push $nuGetPackage
	}
}