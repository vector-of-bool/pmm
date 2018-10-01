& docker build -t pmm-tester .
if ($LASTEXITCODE) {
    throw "Failed to build container image"
}

$here = $PSScriptRoot
$MountArgs = "-v$($here):/host/source", "-v$($here)/build/in-docker:/host/build"
& docker run @MountArgs -ti --rm pmm-tester cmake -H/host/source -B/host/build -GNinja
