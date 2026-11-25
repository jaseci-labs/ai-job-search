"""Helpers for the tests that pin the wording of the docs and command specs."""

import importlib.util, re, subprocess, unittest;
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
def doc(rel: str) -> str {
    return (REPO / rel).read_text(encoding="utf-8");
}

"""The text after the first `start` up to the first match of the regex `stop`, or to the end."""
def section(text: str, start: str, stop: str = "^#{1,4} ") -> str {
    rest: str = text[text.index(start) + len(start):];
    end: re.Match | None = re.search(stop, rest, re.MULTILINE);
    return rest[:end.start()] if end else rest;
}

"""The body of the `## title` section."""
def h2(text: str, title: str) -> str {
    return section(text, f"\n## {title}\n", "^## ");
}

"""The text between the first `start` and the next `stop`, both required."""
def between(text: str, start: str, stop: str) -> str {
    rest: str = text[text.index(start) + len(start):];
    return rest[:rest.index(stop)];
}

def expect(t: unittest.TestCase, text: str, *phrases: str) -> None {
    for phrase in phrases {
        with t.subTest(phrase=phrase) {
            t.assertIn(phrase, text);
        }
    }
}

def expect_not(t: unittest.TestCase, text: str, *phrases: str) -> None {
    for phrase in phrases {
        with t.subTest(absent=phrase) {
            t.assertNotIn(phrase, text);
        }
    }
}

def expect_re(t: unittest.TestCase, text: str, *patterns: str) -> None {
    for pattern in patterns {
        with t.subTest(pattern=pattern) {
            t.assertRegex(text, pattern);
        }
    }
}

"""Each case is (file, heading or None for the whole file, phrases it must hold)."""
def expect_all(t: unittest.TestCase, cases: list[tuple[str, str | None, list[str]]]) -> None {
    for (rel, heading, phrases) in cases {
        text: str = doc(rel) if heading is None else section(doc(rel), heading);
        with t.subTest(file=rel, heading=heading) {
            expect(t, text, *phrases);
        }
    }
}

def lint_skills_passes(t: unittest.TestCase) -> None {
    if importlib.util.find_spec("yaml") is None {
        t.skipTest("PyYAML not installed");
    }
    result: subprocess.CompletedProcess = subprocess.run(
        tool("lint_skills"), cwd=REPO, capture_output=True, text=True
    );
    t.assertEqual(result.returncode, 0, result.stdout + result.stderr);
}
