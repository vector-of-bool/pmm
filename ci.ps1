param(
    # Run the Docker tests
    [switch]
    $RunDockerTests,
    # Forcibly set CC and CXX to MSVC cl.exe
    [switch]
    $ForceMSVC
)

$ErrorActionPreference = "Stop"

$cc = ""
$cxx = ""

if ($PSVersionTable.OS.StartsWith("Darwin")) {
    # We're on macOS, and we need a newer GCC for the FS TS
    & brew install gcc6
    if ($LASTEXITCODE) {
        throw "Brew installation failed!"
    }
    $cc = (Get-ChildItem '/usr/local/Cellar/gcc@6/*/*/gcc').FullName
    $cxx = (Join-Path (Split-Path $cc -Parent) "g++")
}

if ($ForceMSVC) {
    $cc = "cl"
    $cxx = "cl"
}

$cmake = (Get-Command -Name cmake).Source
$ninja = (Get-Command -Name ninja).Source

if (! $cmake) {
    throw "No CMake installed?"
}
if (! $ninja) {
    throw "No Ninja found?"
}

$source_dir = $PSScriptRoot
$bin_dir = Join-Path $source_dir "ci-build"

if (TEst-Path $bin_dir) {
    Remove-Item -Recurse $bin_dir -Force
}

$run_docker_tests = "FALSE"
if ($RunDockerTests) {
    $run_docker_tests = "TRUE"
}

& $cmake -E env CC=$cc CXX=$cxx $cmake -GNinja "-DRUN_DOCKER_TESTS:BOOL=$run_docker_tests" "-H$source_dir" "-B$bin_dir"
if ($LASTEXITCODE) {
    throw "CMake configure failed [$LASTEXITCODE]"
}

& $cmake -E env CC=$cc CXX=$cxx $cmake --build $bin_dir
if ($LASTEXITCODE) {
    throw "CMake build failed [$LASTEXITCODE]"
}

$cm_dir = Split-Path $cmake -Parent
$ctest = Join-Path $cm_dir "ctest"
& $cmake -E chdir $bin_dir $ctest -j6 --output-on-failure
if ($LASTEXITCODE) {
    throw "CTest failed [$LASTEXITCODE]"
}
