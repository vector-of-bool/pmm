[CmdletBinding(PositionalBinding=$false)]
param(
    # Run the Docker tests
    [Parameter()]
    [switch]
    $RunDockerTests,
    # Forcibly set CC and CXX to MSVC cl.exe
    [Parameter()]
    [switch]
    $ForceMSVC,
    # Ignore the `ci/` tests directory
    [Parameter()]
    [switch]
    $NoCITestDir,
    # Do not delete the build directory before running
    [Parameter()]
    [switch]
    $NoClean,
    # Run tests matching the given regular expression
    [Parameter()]
    [regex]
    $TestRegex
)

$ErrorActionPreference = "Stop"

if ($PSVersionTable.OS -and $PSVersionTable.OS.StartsWith("Darwin")) {
    # We're on macOS, and we need a newer GCC for the FS TS
    & brew install "gcc@8"
    if ($LASTEXITCODE) {
        throw "Brew installation failed!"
    }
    $cc = Get-ChildItem '/usr/local/Cellar/gcc@8/*/bin/gcc-8'
    $cxx = Get-ChildItem '/usr/local/Cellar/gcc@8/*/bin/g++-8'
    $env:CC = $cc.FullName
    $env:CXX = $cxx.FullName
}

if ($ForceMSVC) {
    $env:CC = "cl"
    $env:CXX = "cl"
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

if (-not $NoClean -and (Test-Path $bin_dir)) {
    Remove-Item -Recurse $bin_dir -Force
}

$run_docker_tests = "FALSE"
if ($RunDockerTests) {
    $run_docker_tests = "TRUE"
}
$no_ci_test_dir = "FALSE"
if ($NoCITestDir) {
    $no_ci_test_dir = "TRUE"
}

& $cmake -GNinja `
    "-DRUN_DOCKER_TESTS:BOOL=$run_docker_tests" `
    "-DNO_CI_TEST_DIR:BOOL=$no_ci_test_dir" `
    "-H$source_dir" "-B$bin_dir"
if ($LASTEXITCODE) {
    throw "CMake configure failed [$LASTEXITCODE]"
}

& $cmake --build $bin_dir
if ($LASTEXITCODE) {
    throw "CMake build failed [$LASTEXITCODE]"
}

$cm_dir = Split-Path $cmake -Parent
$ctest = Join-Path $cm_dir "ctest"
$args = @()
if ($VerbosePreference) {
    $args += "-V"
}

if ($TestRegex) {
    $args += "-R", "$TestRegex"
}

& $cmake -E chdir $bin_dir $ctest -j6 --output-on-failure @args
if ($LASTEXITCODE) {
    throw "CTest failed [$LASTEXITCODE]"
}
