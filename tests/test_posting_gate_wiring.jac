import re, unittest;
import from pathlib { Path }

glob CLAUDE: Path = Path(__file__).resolve().parent.parent / ".claude",
     SKILL_DIR: str = "skills/job-application-assistant",
     AGENTS: tuple[str, ...] = ("agents/posting-fetcher.md", "agents/posting-scorer.md");

def doc(name: str) -> str {
    return (CLAUDE / name).read_text(encoding="utf-8");
}

"""The first group of `pattern` in `text`; the test fails when the section is missing."""
def section(text: str, pattern: str, flags: int = re.DOTALL) -> str {
    found: re.Match[str] | None = re.search(pattern, text, flags);
    assert found is not None, f"no section matches {pattern}";
    return found.group(1);
}

class GateWiring(unittest.TestCase) {
    def test_archive_stores_cleaned_text_with_counts_only {
        step6b: str = section(
            doc("commands/apply.md"),
            "### Step 6b: Record the Application(.*?)(?=### Application-Form Fields)",
        );
        item7: str = section(
            step6b, "7\\. \\*\\*Archive the posting now\\.\\*\\*(.*?)(?=\\n\\n|\\Z)"
        );
        for word in ("verbatim", "posting_guard", "counts") {
            self.assertIn(word, item7);
        }
        self.assertRegex(
            item7, "never .*excerpt", "removed content must not be re-archived as quotes"
        );
    }

    def test_interview_step1_gates_the_archived_posting_and_its_fetch_fallback {
        step1: str = section(
            doc("commands/interview.md"),
            "## Step 1: Load the Application Context(.*?)(?=\\n## Step 2)",
        );
        self.assertIn("posting_guard", step1);
        self.assertIn("--text", step1);
        self.assertIn(
            "posting_guard", section(step1, "2\\. \\*\\*Fallbacks\\*\\*(.*?)(?=\\n3\\. )")
        );
    }

    def test_skill_step1_names_the_gate {
        text: str = doc(f"{SKILL_DIR}/SKILL.md");
        self.assertIn(
            "posting_guard", section(text, "### Step 1: Research & Evaluate Fit(.*?)(?=### Step 2)")
        );
        version: re.Match[str] | None = re.search(
            "^framework_version: (\\d+)\\.(\\d+)\\.(\\d+)$", text, re.MULTILINE
        );
        self.assertIsNotNone(version);
        self.assertGreaterEqual(tuple([int(part) for part in version.groups()]), (1, 3, 6));
    }

    def test_outcome_fresh_fetch_is_gated {
        self.assertIn("posting_guard", doc("commands/outcome.md"));
    }

    def test_scratchpad_is_guarded_everywhere_the_gate_writes {
        for name in ("commands/apply.md", *AGENTS) {
            with self.subTest(doc=name) {
                self.assertNotRegex(
                    doc(name),
                    "\\$SCRATCHPAD/",
                    "use ${SCRATCHPAD:?...} so an unset variable fails loudly",
                );
                self.assertIn("${SCRATCHPAD:?", doc(name));
            }
        }
    }

    def test_fetch_agents_can_discover_installed_portals {
        for name in AGENTS {
            with self.subTest(agent=name) {
                self.assertIn(
                    "Glob",
                    section(doc(name), "^tools:\\s*(.*)$", re.M),
                    "rung 1 needs to find .agents/skills/*/SKILL.md",
                );
            }
        }
    }

    def test_09_trust_boundary_names_the_gate {
        text: str = doc(f"{SKILL_DIR}/09-web-research.md");
        self.assertIn("posting_guard", section(text, "## Trust boundary(.*?)(?=\\n## )"));
        self.assertIn("framework_version: 1.2.0", text);
    }
}

with entry:__main__ {
    unittest.main();
}
