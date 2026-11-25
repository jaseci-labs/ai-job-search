import re;
import unittest;
import from pathlib { Path }

glob REPO: Path = Path(__file__).resolve().parent.parent;

def doc(rel: str) -> str;

def command(name: str) -> str;

def skill(name: str) -> str;

def between(text: str, start: str, end: str) -> str;

def under(text: str, heading: str) -> str;

def parts(text: str, level: str) -> dict[str, str];

def h2(text: str) -> list[str];

def quoted(text: str) -> list[str];

def bash_block(text: str, after: str) -> str;

def check(
    fixture: unittest.TestCase, text: str, present: list[str], absent: list[str] = []
) -> None;
