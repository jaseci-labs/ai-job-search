"""How the tests start the project's tools: through the jobsearch app they run in."""

import os;
import sys;
import unittest;
import from pathlib { Path }
import from unittest { mock }

glob REPO: Path = Path(__file__).resolve().parent.parent;

"""The app's own entry file, which the interpreter running the tests was started on."""
def app_main -> str;

"""The command line that runs one tool: extend it with the tool's arguments."""
def tool(name: str) -> list[str];

"""An environment in which the tools take `root` as the repository."""
def rooted(`root: any, env: any = None) -> dict[str, str];

"""For the rest of a test, have the tools it starts take `root` as the repository."""
def root_at(fixture: unittest.TestCase, `root: any) -> None;
