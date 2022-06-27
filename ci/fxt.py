import subprocess
import textwrap
from contextlib import contextmanager
from pathlib import Path
from typing import Callable, Iterator, MutableSequence, Protocol

from pytest import TempPathFactory, fixture

ROOT = Path(__file__).resolve().parent.parent


@fixture(scope='session')
def pmm_dir() -> Path:
    return ROOT


class CMakeCommandWriterFunction(Protocol):

    def __call__(self, *argv: str) -> None:
        ...


class CMakeFileWriter:

    def __init__(self, into: MutableSequence[str]) -> None:
        self._into = into

    def _quote(self, s: str) -> str:
        if any(bad in s for bad in '${} \n[]()"'):
            return '"' + s.replace('"', '\\"') + '"'
        return s

    def __getattr__(self, n: str) -> CMakeCommandWriterFunction:

        def _write(*argv: str) -> None:
            line = f'{n.lower()}(' + ' '.join(self._quote(s) for s in argv) + ')'
            self._into.append(line)

        return _write


class CMakeProject:

    def __init__(self, dirpath: Path) -> None:
        self.root = dirpath

    @contextmanager
    def write_CMakeLists(self) -> Iterator[CMakeFileWriter]:
        """Write the CMakeLists.txt file"""
        lines: list[str] = []
        yield CMakeFileWriter(lines)
        content = '\n'.join(lines) + '\n'
        print(f'Generated CMakeLists.txt: {textwrap.indent(content, prefix="  ")}')
        self.root.joinpath('CMakeLists.txt').write_text(content, encoding='utf-8')

    def configure(self) -> None:
        cmd = ['cmake', '-S', str(self.root), '-B', str(self.root / '_build')]
        cmd.append(f'-DPMM_INCLUDE={ROOT / "pmm.cmake"}')
        cmd.append(f'-DPMM_URL={ROOT.joinpath("pmm").as_uri()}')
        print(f'Run command: {cmd=}')
        subprocess.check_call(cmd)

    def build(self) -> None:
        cmd = ['cmake', '--build', str(self.root / '_build')]
        subprocess.check_call(cmd)

    def write(self, fpath: Path | str, content: str, *, dedent: bool = True) -> None:
        fpath = Path(fpath)
        assert not fpath.is_absolute(), f'Path [{fpath=}] shouuld be a relative path'
        if dedent:
            content = textwrap.dedent(content)
        self.root.joinpath(fpath).write_text(content)


CMakeProjectFactory = Callable[[str], CMakeProject]


@fixture(scope='session')
def tmp_project_factory(tmp_path_factory: TempPathFactory) -> CMakeProjectFactory:

    def fac(name: str) -> CMakeProject:
        tdir = tmp_path_factory.mktemp(f'proj-{name}')
        return CMakeProject(tdir)

    return fac
