"""Helpers for the tests that pin the wording of the docs and command specs."""

import importlib.util;
import re;
import subprocess;
import unittest;
import from pathlib { Path }

glob REPO: Path = Path(__file__).resolve().parent.parent,
     APPLY: str = ".claude/commands/apply.md",
     OUTCOME: str = ".claude/commands/outcome.md",
     GMAIL_SYNC: str = ".claude/commands/gmail-sync.md",
     HTML_REPORT: str = ".claude/commands/html-report.md",
     INTERVIEW: str = ".claude/commands/interview.md",
     NOTION_SYNC: str = ".claude/commands/notion-sync.md",
     RANK: str = ".claude/commands/rank.md",
     ASSISTANT: str = ".claude/skills/job-application-assistant/SKILL.md",
     EVALUATION: str = ".claude/skills/job-application-assistant/04-job-evaluation.md",
     SCRAPER: str = ".claude/skills/job-scraper/SKILL.md";

"""The text of a repository file."""
def doc(rel: str) -> str;

"""The text after the first `start` up to the first match of the regex `stop`, or to the end."""
def section(text: str, start: str, stop: str = "^#{1,4} ") -> str;

"""The body of the `## title` section."""
def h2(text: str, title: str) -> str;

"""The text between the first `start` and the next `stop`, both required."""
def between(text: str, start: str, stop: str) -> str;

def expect(t: unittest.TestCase, text: str, *phrases: str) -> None;

def expect_not(t: unittest.TestCase, text: str, *phrases: str) -> None;

def expect_re(t: unittest.TestCase, text: str, *patterns: str) -> None;

"""Each case is (file, heading or None for the whole file, phrases it must hold)."""
def expect_all(t: unittest.TestCase, cases: list[tuple[str, str | None, list[str]]]) -> None;

def lint_skills_passes(t: unittest.TestCase) -> None;
