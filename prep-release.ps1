<#
.SYNOPSIS
    Prepares a PMM version for release.
.DESCRIPTION
    Prepares a PMM version for release by checking out the code and placing it in the correct path for deployment
#>
[CmdletBinding(PositionalBinding=$false)]
param (
    # The version of PMM that we will prepare. Must name an existing Git tag.
    [Parameter(Mandatory)]
    [string]
    $Version,
    # Forcibly replace any existing directory for this version
    [Parameter()]
    [switch]
    $ForceReplace
)

$ErrorActionPreference='Stop'

$here = Resolve-Path (Split-Path -Parent $MyInvocation.MyCommand.Source)

Write-Host 'Fetching all tags...'
& git fetch --tags --quiet
if ($LASTEXITCODE) {
    throw "Fetching tags failed"
}

$tag_path = [System.IO.Path]::GetFullPath("$here/.git/refs/tags/$Version")

if (! (Test-Path $tag_path -PathType Leaf)) {
    throw "'$Version' is not an existing Git tag"
}

$dest_path = Join-Path $here $Version

if ((Test-Path $dest_path -PathType Container) -and (! $ForceReplace)) {
    throw "Deployment destination [$dest_path] already exists. Use '-ForceReplace' to replace it."
}

$pmm_dir = Join-Path $here "pmm"
$latest_info_file = Join-Path $here "latest-info.cmake"

Write-Host "Checking out code for '$Version'"
& git checkout $Version -- $pmm_dir $latest_info_file
if ($LASTEXITCODE) {
    throw "Failed to checkout version '$Version' [$LASTEXITCODE]"
}

Write-Host "Preparing changes..."
if (Test-Path $dest_path) {
    Remove-Item $dest_path -Recurse
}
Move-Item $pmm_dir $dest_path

& git reset HEAD -- $pmm_dir
if ($LASTEXITCODE) {
    throw "'git reset' failed for $pmm_dir"
}

& git reset HEAD -- $latest_info_file
if ($LASTEXITCODE) {
    throw "'git reset' fialed for $latest_info_file"
}

Write-Host "'$Version' is ready for deployment. Add and commit changes."
