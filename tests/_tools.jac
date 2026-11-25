import os;
import sys;
import unittest;
import from pathlib { Path }
import from unittest { mock }

glob REPO: Path = Path(__file__).resolve().parent.parent;

def app_main -> str;

def tool(name: str) -> list[str];

def rooted(`root: any, env: any = None) -> dict[str, str];

def root_at(fixture: unittest.TestCase, `root: any) -> None;
