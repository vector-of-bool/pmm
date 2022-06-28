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


class CMakeProject:

    def __init__(self, dirpath: Path) -> None:
        self.root = dirpath

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
