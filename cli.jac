import runpy;
import sys;
import unittest;
import from pathlib { Path }

glob ROOT: Path = Path(__file__).resolve().parent;

def tool_names -> list[str];
def module_of(name: str) -> str;
def usage -> str;
def run_tests(names: list[str]) -> int;
def main -> int;

with entry {
    sys.exit(main());
}
