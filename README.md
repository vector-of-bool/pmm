# PMM - The Package Manager Manager

PMM is a module for CMake that manages... package managers.

## Wha- Why?

People hate installing new software. Especially when they already have a
perfectly working tool already present. PMM uses the CMake scripting
language to manage external packaging tools. PMM will automatically
download, install, and control package managers from within your CMake
project.

(As you are reading this, only Conan is supported.)

## But This is Just *Another* Tool I have to Manager!

Never fear! PMM is the lowest-maintenance software you will ever use.

## How Do I Use PMM?

Using PMM is simple:

1. Download the `pmm.cmake` file (available at the top level of this
   respository), and place it at the top level of your repository
   (alongside your `CMakeLists.txt`).
2. In your `CMakeLists.txt`, add a line `include(pmm.cmake)`.
3. Call the `pmm()` CMake function.

That's it! The `pmm.cmake` file is just 26 (significant) lines of source
code. Take a look inside if you doubt.

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

```text
pmm(
    [CONAN {AUTO}]
)
```

## `CONAN` PMM mode

In `CONAN` mode, PMM will find, obtain, and use Conan to manage project
packages.

PMM will always use the `cmake_paths` Conan generator. After installing for
the project, includes `cmake_paths.cmake`, which sets `CMAKE_MODULE_PATH`
and `CMAKE_PREFIX_PATH`, ready to be used for `find_package()` by the
project.

The nitty-gritter of how this is done:

1. Check for the `CONAN_EXECUTABLE` variable. If found, it is used.
2. Try to find a `conan` executable. Searches:
    1. Any `pyenv` versions in the user home directory
    2. `~/.local/bin` for user-mode install binaries
    3. `C:/Python{36,27,}/Scripts` for Conan installations
    4. Anything else on `PATH`
3. If still no Conan, attempts to obtain one automatically, trying first
   Python 3, then Python 2:
    1. Check for a `venv` or `virtualenv` executable Python module.
    2. With a virtualenv module, creates a Python virtualenv in the
        project's build directory.
    3. Installs Conan in *within the build directory*, and uses that.

`CONAN` requires a sub-mode. Currently there is only `AUTO`.

### `AUTO` Conan mode

Passing `AUTO` for `CONAN` requests automatic mode, where PMM will use the
`conanfile.txt` or `conanfile.py` in your project to download and install
dependencies.

This mode will also
