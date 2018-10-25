# PMM - The Package Manager Manager

PMM is a module for CMake that manages... package managers.

## Wha- Why?

People hate installing new software. Especially when they already have a
perfectly working tool present. PMM uses the CMake scripting
language to manage external packaging tools. PMM will automatically
download, install, and control package managers from within your CMake
project.

(As you are reading this, only Conan and VCPKG are supported.)

## But This is Just *Another* Tool I have to Manage!

Never fear! PMM is the lowest-maintenance software you will ever use.

## How Do I Use PMM?

Using PMM is simple:

1. Download the `pmm.cmake` file (available at the top level of this
   respository), and place it at the top level of your repository
   (alongside your `CMakeLists.txt`).
2. In your `CMakeLists.txt`, add a line `include(pmm.cmake)`.
3. Call the `pmm()` CMake function.

That's it! The `pmm.cmake` file is just 23 significant lines. Take a look inside
if you doubt.

## Wait... It's Downloading a Bunch of Stuff!

Precisely! `pmm.cmake` is just a bootstrapper for the real PMM code, which
can be found in the `pmm/` directory in the repository. The content is
served over HTTPS from the `gh-pages` branch of the PMM repository, so it is all publicly visible.

## I Don't Want to Automatically Download and Run Code from the Internet

Great! I sympathize, but remember: If you run `apt`, `yum`, `pip`, or even
`conan`, you are automatically downloading and running code from the
internet. It's all about whose code you *trust*.

Even still, you can host the PMM code yourself: Download the `pmm/`
directory as you want it, and modify the `pmm.cmake` script to download
from your alternate location (eg, a corporate engineering intranet server).

## Will PMM Updates Silently Break my Build?

Nope. `pmm.cmake` will never automatically change the version of PMM that
it uses, and the files served will never be modified in-place: New versions
will be *added,* but old versions will remain unmodified.

PMM will notify you if a new version is available, but it won't be annoying
about it, and you can always disable this nagging by setting
`PMM_IGNORE_NEW_VERSION` before including `pmm.cmake`.

## How do I Change the PMM Version?

There are two ways:

1. Set `PMM_VERSION` before including the `pmm.cmake` script.
2. Modify the `PMM_VERSION_INIT` value at the top of `pmm.cmake`.

Prefer (1) for conditional/temporary version changes, and (2) for permanent
version changes.

## How do I Change the Download Location for PMM?

For permanent changes, set `PMM_URL` and/or `PMM_URL_BASE` in `pmm.cmake`.
For temporary changes, set `PMM_URL` before including `pmm.cmake`

# The `pmm()` Function

The only interface to PMM (after including `pmm.cmake`) is the `pmm()`
CMake function. Using it is very simple. At the time or writing, `pmm()`
only supports Conan, but other packaging solutions will be supported in the
future.

The `pmm()` signature:

```cmake
pmm(
    # Enable verbose logging
    [VERBOSE]
    # Enable debug logging (implies VERBOSE)
    [DEBUG]
    # Use Conan
    [CONAN
        # Set additional --setting flags
        [SETTINGS ...]
        # Set additional --option flags
        [OPTIONS ...]
        # Set the --build option. (Default is `missing`)
        [BUILD <policy>]
    ]
    # Use vcpkg
    [VCPKG
        # Specify the revision of vcpkg that you want to use (required)
        REVISION <rev>
        # Ensure the given packages are installed using vcpkg
        [REQUIRES [req [...]]]
    ]
)
```

## `CONAN` PMM mode

In `CONAN` mode, PMM will find, obtain, and use Conan to manage project
packages.

PMM will always use the `cmake` Conan generator, and will define imported
targets for consumption (Equivalent of `conan_basic_setup(TARGETS)`). It will
also set `CMAKE_PREFIX_PATH` and `CMAKE_MODULE_PATH` for you to use
`find_package()` and `include()` against the installed dependencies.

> **NOTE:** No other CMake variables from regular Conan usage are defined.

`CONAN` mode requires a `conanfile.txt` or `conanfile.py` in your project
source directory. It will run `conan install` against this file to obtain
dependencies for your project.

The nitty-gritty of how PMM finds/obtains Conan:

1. Check for the `CONAN_EXECUTABLE` variable. If found, it is used.
2. Try to find a `conan` executable. Searches:
    1. Any `pyenv` versions in the user home directory
    2. `~/.local/bin` for user-mode install binaries
    3. `C:/Python{36,27,}/Scripts` for Conan installations
    4. Anything else on `PATH`
3. If still no Conan, attempts to obtain one automatically, trying first
   Python 3, then Python 2:
    1. Check for a `venv` or `virtualenv` executable Python module.
    2. With a user-local virtualenv.
    3. Installs Conan *within the created virtualenv* and uses Conan from there.

### PMM Will Not do _Everything_ for You

While PMM will ensure that Conan has been executed for you as part of your
configure stage, it is up to you to provide a Conanfile that Conan can consume
to get your dependency information.

You will still need to read the Conan documentation to understand the basics of
how to declare and consume your dependencies.

## `VCPKG` PMM mode

In `VCPKG` mode, PMM will download the vcpkg repository at the given
`REVISION`, build the `vcpkg` tool, and manage the package installation in a
use-local data directory.

`REVISION` should be a git tree-ish (A revision number (preferred), branch,
or tag) that you could `git checkout` from the vcpkg repository. PMM will
download the specified commit from GitHub and build the `vcpkg` command line
tool from source. **You will need `std::filesystem` or `std::experimental::filesystem` support from your
compiler and standard library.**

`REQUIRES` is a list of packages that you would like to install using the
`vcpkg` command line tool.

When using PMM, you do not need to use the `vcpkg.cmake` CMake toolchain
file: PMM will take care of this aspect for you.

After calling `pmm(VCPKG)`, all you need to do is `find_package()` the
packages that you want to use.

# Helper Commands

Executing PMM in script mode provides some additional helper commands to work
with your project.

> NOTE: This will create a local copy of the PMM code in a `_pmm` directory. It
> is safe to delete or `.gitignore` this directory.

Get help with the `/Help` option:

```sh
> cmake -P pmm.cmake /Help
```

As an example, you can build, test, and upload your package all in one go with
this command:

```sh
> cmake -P pmm.cmake /Conan /Create /Upload /Ref my-user/unstable /Remote some-remote
```
